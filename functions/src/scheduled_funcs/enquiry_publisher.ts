// ──────────────────────────────────────────────────────────────────────────────
// File: src/schedule/publishers/enquiry_publisher.ts
// Purpose: Publishes new enquiries; runs at 00:00 and 12:00 Rome working days
// ──────────────────────────────────────────────────────────────────────────────
import { FieldValue, getFirestore } from "firebase-admin/firestore";
import { logger } from "firebase-functions";

import { computeStageEnds } from "../utils/compute_stage_ends";
import {
  tokeniseAttachmentsIfAny,
  readAuthorTeam,
  queueDraftDelete,
  stageUpdatePayload,
} from "../utils/publish_helpers";
import { createUnreadForAllUsers } from "../utils/unread_post_generator";

const db = getFirestore();

/** Helper function extracted for use by orchestrator */
export async function doEnquiryPublish(): Promise<void> {
  const publishedAt = FieldValue.serverTimestamp();

  const snap = await db
    .collection("enquiries")
    .where("isPublished", "==", false)
    .get();
  if (snap.empty) {
    logger.info("[doEnquiryPublish] No pending enquiries.");
    return;
  }

  const writer = db.bulkWriter();
  let published = 0;
  let draftsQueued = 0;

  for (const doc of snap.docs) {
    // 1) read stage length and compute new stage end
    const enquiryData = doc.data();
    const stageLength = enquiryData.stageLength ?? 4;
    const stageEndsDate = computeStageEnds(stageLength, {
      hour: 19,
      minute: 59,
    });

    // 2) publish fields
    writer.update(doc.ref, {
      isPublished: true,
      publishedAt,
      ...stageUpdatePayload(stageEndsDate),
    });
    published += 1;

    // 3) tokenise attachments if any
    await tokeniseAttachmentsIfAny(writer, doc.ref, doc.get("attachments"));

    // 4) delete draft for author team
    const team = await readAuthorTeam(doc.ref);
    if (!team) {
      logger.warn(
        `[doEnquiryPublish] No team found for ${doc.id}, skipping draft delete.`,
      );
      continue;
    }
    queueDraftDelete(writer, team, doc.id);
    draftsQueued += 1;

    await createUnreadForAllUsers(
      writer,
      "enquiry",
      `RE #${enquiryData.enquiryNumber} - ${enquiryData.title}`,
      doc.id,
      true,
      {},
    );
  }

  await writer.close();
  logger.info(
    `[doEnquiryPublish] Published ${published} enquiries; queued ${draftsQueued} draft deletions.`,
  );
}

// ✅ Note: enquiryPublisher is no longer exported directly.
// It is called by the orchestrator (orchestrate0000, orchestrate1200).
// Legacy export commented out:
/*
export const enquiryPublisher = onSchedule(
  {
    region: SCHED_REGION_ROME,
    schedule: "0 0,12 * * *",
    timeZone: ROME_TZ,
    timeoutSeconds: TIMEOUT_SECONDS,
  },
  async (): Promise<void> => {
    await doEnquiryPublish();
  },
);
*/
