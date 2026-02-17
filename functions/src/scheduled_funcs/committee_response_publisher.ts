// ──────────────────────────────────────────────────────────────────────────────
// File: src/schedule/publishers/committee_response_publisher.ts
// Purpose: Publishes RC response when all windows closed; daily 00:00 Rome
// ──────────────────────────────────────────────────────────────────────────────
import { getFirestore, Timestamp } from "firebase-admin/firestore";
import { logger } from "firebase-functions";
import { DateTime } from "luxon";

import { ROME_TZ } from "../common/config";
import { publishResponses } from "../utils/publish_responses";
import { isWorkingDay } from "../working_day";

const db = getFirestore();

/** Helper function extracted for use by orchestrator */
export async function doCommitteeResponsePublish(): Promise<void> {
  const nowRome = DateTime.now().setZone(ROME_TZ);
  const nowTs = Timestamp.now();

  // working day check
  if (!isWorkingDay(nowRome)) {
    logger.info(
      `[doCommitteeResponsePublish] ${nowRome.toISO()} not a working day; skipping.`,
    );
    return;
  }

  // find relevant enquiries
  const enquiriesSnap = await db
    .collection("enquiries")
    .where("isOpen", "==", true)
    .where("isPublished", "==", true)
    .where("teamsCanRespond", "==", false)
    .where("teamsCanComment", "==", false)
    .where("stageEnds", "<", nowTs)
    .get();
  if (enquiriesSnap.empty) {
    logger.info("[doCommitteeResponsePublish] No qualifying enquiries.");
    return;
  }

  // loop through enquiries and look for responses to publish
  let processed = 0;
  let published = 0;
  const writer = db.bulkWriter();
  for (const enquiryDoc of enquiriesSnap.docs) {
    const publishResult = await publishResponses(
      writer,
      "doCommitteeResponsePublish",
      enquiryDoc,
      true,
    );
    processed += 1;
    published += publishResult.publishedNumber;
    if (publishResult.success == false) {
      logger.info(
        `[doCommitteeResponsePublish] Enquiry ${enquiryDoc.id} failed with reason: ${publishResult.failReason}.`,
      );
      // could trigger email to RC if they miss a deadline
    }
  }
  await writer.close();
  logger.info(
    `[doCommitteeResponsePublish] Processed ${processed} enquiries; published ${published} committee responses.`,
  );
}

// ✅ Note: committeeResponsePublisher is no longer exported directly.
// It is called by the orchestrator (orchestrate0000).
// Legacy export commented out:
/*
export const committeeResponsePublisher = onSchedule(
  {
    region: SCHED_REGION_ROME,
    schedule: "0 0 * * *",
    timeZone: ROME_TZ,
    timeoutSeconds: TIMEOUT_SECONDS,
  },
  async (): Promise<void> => {
    await doCommitteeResponsePublish();
  },
);
*/
