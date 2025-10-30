// ──────────────────────────────────────────────────────────────────────────────
// File: src/scheduled_funcs/team_response_publisher.ts
// Purpose: Publishes competitor responses after stage end; nightly 20:00 Rome
// ──────────────────────────────────────────────────────────────────────────────
import { getFirestore, Timestamp } from "firebase-admin/firestore";
import { logger } from "firebase-functions";
import { onSchedule } from "firebase-functions/v2/scheduler";

import { SCHED_REGION_ROME, ROME_TZ } from "../common/config";
import { publishResponses } from "../utils/publish_responses";

const db = getFirestore();

export const teamResponsePublisher = onSchedule(
  { region: SCHED_REGION_ROME, schedule: "0 20 * * *", timeZone: ROME_TZ },
  async (): Promise<void> => {
    const nowTs = Timestamp.now();

    // find relevant enquiries
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

    // loop through enquiries and look for responses to publish
    let processed = 0;
    let published = 0;
    const writer = db.bulkWriter();
    for (const enquiryDoc of enquiriesSnap.docs) {
      const publishResult = await publishResponses(
        writer,
        "teamResponsePublisher",
        enquiryDoc,
        true,
      );
      processed += 1;
      published += publishResult.publishedNumber;
      if (publishResult.success == false) {
        logger.info(
          `[teamResponsePublisher] Enquiry ${enquiryDoc.id} failed with reason: ${publishResult.failReason}.`,
        );
      }
    }
    await writer.close();
    logger.info(
      `[teamResponsePublisher] Processed ${processed} enquiries; published ${published} responses.`,
    );
  },
);
