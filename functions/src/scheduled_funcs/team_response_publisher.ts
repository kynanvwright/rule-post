// ──────────────────────────────────────────────────────────────────────────────
// File: src/schedule/publishers/team_response_publisher.ts
// Purpose: Publishes competitor responses after stage end; nightly 20:00 Rome
// ──────────────────────────────────────────────────────────────────────────────
import { FieldValue, getFirestore, Timestamp } from "firebase-admin/firestore";
import { logger } from "firebase-functions";
import { onSchedule } from "firebase-functions/v2/scheduler";

import { SCHED_REGION_ROME, ROME_TZ } from "../../common/config";
import { computeStageEnds } from "../../utils/compute_stage_ends";
import {
  tokeniseAttachmentsIfAny,
  readAuthorTeam,
  queueDraftDelete,
  stageUpdatePayload,
} from "../../utils/helpers";

const db = getFirestore();

export const teamResponsePublisher = onSchedule(
  { region: SCHED_REGION_ROME, schedule: "0 20 * * *", timeZone: ROME_TZ },
  async (): Promise<void> => {
    const nowTs = Timestamp.now();
    const publishedAt = FieldValue.serverTimestamp();

    const enquiriesSnap = await db
      .collection("enquiries")
      .where("isPublished", "==", true)
      .where("isOpen", "==", true)
      .where("teamsCanRespond", "==", true)
      .where("stageEnds", "<", nowTs)
      .get();

    if (enquiriesSnap.empty) {
      logger.info("[teamResponsePublisher] No qualifying enquiries.");
      return;
    }

    const writer = db.bulkWriter();
    let totalResponsesPublished = 0;

    for (const enquiryDoc of enquiriesSnap.docs) {
      const enquiryRef = enquiryDoc.ref;

      // Try ordered by createdAt
      let unpublishedSnap: FirebaseFirestore.QuerySnapshot;
      try {
        unpublishedSnap = await enquiryRef
          .collection("responses")
          .where("isPublished", "==", false)
          .orderBy("createdAt", "asc")
          .get();
      } catch {
        unpublishedSnap = await enquiryRef
          .collection("responses")
          .where("isPublished", "==", false)
          .get();
        // stable ordering fallback
        const sorted = [...unpublishedSnap.docs].sort(
          (a, b) =>
            (a.get("createdAt")?.toMillis?.() ?? 0) -
            (b.get("createdAt")?.toMillis?.() ?? 0),
        );
        for (let i = 0; i < sorted.length; i++) {
          writer.update(sorted[i].ref, {
            isPublished: true,
            responseNumber: i + 1,
            publishedAt,
          });
          await tokeniseAttachmentsIfAny(
            writer,
            sorted[i].ref,
            sorted[i].get("attachments"),
          );

          const team = await readAuthorTeam(sorted[i].ref);
          if (!team) {
            logger.warn(
              `[teamResponsePublisher] No team found for ${sorted[i].id}, skipping draft delete.`,
            );
          } else {
            queueDraftDelete(writer, team, sorted[i].id);
          }
          totalResponsesPublished += 1;
        }
      }

      if (unpublishedSnap && !unpublishedSnap.empty) {
        const docs = unpublishedSnap.docs; // already ordered if try succeeded
        for (let i = 0; i < docs.length; i++) {
          writer.update(docs[i].ref, {
            isPublished: true,
            responseNumber: i + 1,
            publishedAt,
          });
          await tokeniseAttachmentsIfAny(
            writer,
            docs[i].ref,
            docs[i].get("attachments"),
          );

          const team = await readAuthorTeam(docs[i].ref);
          if (!team) {
            logger.warn(
              `[teamResponsePublisher] No team found for ${docs[i].id}, skipping draft delete.`,
            );
          } else {
            queueDraftDelete(writer, team, docs[i].id);
          }
          totalResponsesPublished += 1;
        }
      }

      // advance stage for enquiry
      const newStageEnds = computeStageEnds(5, { hour: 11, minute: 55 });
      writer.update(enquiryRef, {
        teamsCanRespond: false,
        teamsCanComment: true,
        ...stageUpdatePayload(newStageEnds),
      });
    }

    await writer.close();
    logger.info(
      `[teamResponsePublisher] Processed ${enquiriesSnap.size} enquiries; published ${totalResponsesPublished} responses.`,
    );
  },
);
