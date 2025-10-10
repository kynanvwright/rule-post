// ──────────────────────────────────────────────────────────────────────────────
// File: src/schedule/publishers/enquiry_publisher.ts
// Purpose: Publishes new enquiries; runs at 00:00 and 12:00 Rome working days
// ──────────────────────────────────────────────────────────────────────────────
import { FieldValue, getFirestore } from "firebase-admin/firestore";
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

export const enquiryPublisher = onSchedule(
  { region: SCHED_REGION_ROME, schedule: "0 0,12 * * *", timeZone: ROME_TZ },
  async (): Promise<void> => {
    const stageEndsDate = computeStageEnds(4, { hour: 19, minute: 55 });
    const publishedAt = FieldValue.serverTimestamp();

    const snap = await db
      .collection("enquiries")
      .where("isPublished", "==", false)
      .get();
    if (snap.empty) {
      logger.info("[enquiryPublisher] No pending enquiries.");
      return;
    }

    const writer = db.bulkWriter();
    let published = 0;
    let draftsQueued = 0;

    for (const doc of snap.docs) {
      // 1) publish fields
      writer.update(doc.ref, {
        isPublished: true,
        publishedAt,
        ...stageUpdatePayload(stageEndsDate),
      });
      published += 1;

      // 2) tokenise attachments if any
      await tokeniseAttachmentsIfAny(writer, doc.ref, doc.get("attachments"));

      // 3) delete draft for author team
      const team = await readAuthorTeam(doc.ref);
      if (!team) {
        logger.warn(
          `[enquiryPublisher] No team found for ${doc.id}, skipping draft delete.`,
        );
        continue;
      }
      queueDraftDelete(writer, team, doc.id);
      draftsQueued += 1;
    }

    await writer.close();
    logger.info(
      `[enquiryPublisher] Published ${published} enquiries; queued ${draftsQueued} draft deletions.`,
    );
  },
);
