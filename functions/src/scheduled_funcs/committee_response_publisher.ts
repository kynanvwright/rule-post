// ──────────────────────────────────────────────────────────────────────────────
// File: src/schedule/publishers/committee_response_publisher.ts
// Purpose: Publishes RC response when all windows closed; daily 00:00 Rome
// ──────────────────────────────────────────────────────────────────────────────
import { FieldValue, getFirestore, Timestamp } from "firebase-admin/firestore";
import { logger } from "firebase-functions";
import { onSchedule } from "firebase-functions/v2/scheduler";
import { DateTime } from "luxon";

import { SCHED_REGION_ROME, ROME_TZ } from "../../common/config";
import { FinalisedAttachment } from "../../common/types";
import { computeStageEnds } from "../../utils/compute_stage_ends";
import {
  tokeniseAttachmentsIfAny,
  stageUpdatePayload,
} from "../../utils/helpers";
import { isWorkingDay } from "../../working_day";

const db = getFirestore();

export const committeeResponsePublisher = onSchedule(
  { region: SCHED_REGION_ROME, schedule: "0 0 * * *", timeZone: ROME_TZ },
  async (): Promise<void> => {
    const publishedAt = FieldValue.serverTimestamp();
    const nowRome = DateTime.now().setZone(ROME_TZ);
    const nowTs = Timestamp.now();

    if (!isWorkingDay(nowRome)) {
      logger.info(
        `[committeeResponsePublisher] ${nowRome.toISO()} not a working day; skipping.`,
      );
      return;
    }

    const enquiriesSnap = await db
      .collection("enquiries")
      .where("isOpen", "==", true)
      .where("isPublished", "==", true)
      .where("teamsCanRespond", "==", false)
      .where("teamsCanComment", "==", false)
      .where("stageEnds", "<", nowTs)
      .get();
    if (enquiriesSnap.empty) {
      logger.info("[committeeResponsePublisher] No qualifying enquiries.");
      return;
    }

    let processed = 0;
    let published = 0;

    for (const enquiryDoc of enquiriesSnap.docs) {
      const enquiryRef = enquiryDoc.ref;

      try {
        await db.runTransaction(async (tx) => {
          const freshEnquirySnap = await tx.get(enquiryRef);
          if (!freshEnquirySnap.exists) return;

          const e = freshEnquirySnap.data() || {};
          const roundNumber = e.roundNumber as number | undefined;
          if (typeof roundNumber !== "number") return;

          const stillOpen =
            e.isOpen === true &&
            e.isPublished === true &&
            e.teamsCanRespond === false &&
            e.teamsCanComment === false &&
            (e.stageEnds instanceof Timestamp
              ? e.stageEnds.toMillis() < Date.now()
              : false);
          if (!stillOpen) return;

          const respCol = enquiryRef.collection("responses");
          const committeeSnap = await respCol
            .where("roundNumber", "==", roundNumber + 1)
            .where("fromRC", "==", true)
            .where("isPublished", "==", false)
            .get();

          if (committeeSnap.size !== 1) return; // zero or ambiguous → skip

          const committeeDoc = committeeSnap.docs[0];
          tx.update(committeeDoc.ref, { isPublished: true, publishedAt });

          // attachments (read outside tx via helper pattern → but we can safely read again here)
          const snap = await tx.get(committeeDoc.ref);
          const raw = snap.get("attachments");
          const list = Array.isArray(raw) ? (raw as FinalisedAttachment[]) : [];
          if (list.length > 0) {
            // Tokenisation cannot be done inside the transaction (GCS I/O). Defer via queue after tx.
            // We'll mark a flag and process post-tx below.
            tx.update(committeeDoc.ref, { _needsAttachmentTokenising: true });
          }

          // delete draft for the RC team (if present)
          const metaSnap = await committeeDoc.ref
            .collection("meta")
            .doc("data")
            .get();
          const team = metaSnap.exists ? metaSnap.get("authorTeam") : undefined;
          if (!team) {
            logger.warn(
              `[committeeResponsePublisher] No team found for ${committeeDoc.id}.`,
            );
          } else {
            const draftRef = db
              .collection("drafts")
              .doc("posts")
              .collection(team)
              .doc(committeeDoc.id);
            tx.delete(draftRef);
          }

          const nextStageEnds = computeStageEnds(4, { hour: 19, minute: 55 });
          tx.update(enquiryRef, {
            roundNumber: FieldValue.increment(1),
            teamsCanRespond: true,
            teamsCanComment: false,
            ...stageUpdatePayload(nextStageEnds),
          });

          published += 1;
        });

        // Post-tx: if we flagged attachment tokenisation, do it now and clear flag
        const committeeRefs = await enquiryRef
          .collection("responses")
          .where("fromRC", "==", true)
          .orderBy("publishedAt", "desc")
          .limit(1)
          .get();
        if (!committeeRefs.empty) {
          const doc = committeeRefs.docs[0];
          if (doc.get("_needsAttachmentTokenising") === true) {
            const writer = db.bulkWriter();
            await tokeniseAttachmentsIfAny(
              writer,
              doc.ref,
              doc.get("attachments"),
            );
            writer.update(doc.ref, {
              _needsAttachmentTokenising: FieldValue.delete(),
            });
            await writer.close();
          }
        }
      } catch (err) {
        logger.error(
          `[committeeResponsePublisher] Transaction failed for enquiry ${enquiryRef.id}:`,
          err as Error,
        );
      }

      processed += 1;
    }

    logger.info(
      `[committeeResponsePublisher] Processed ${processed} enquiries; published ${published} committee responses.`,
    );
  },
);
