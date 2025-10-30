// ──────────────────────────────────────────────────────────────────────────────
// File: src/schedule/publishers/committee_response_publisher.ts
// Purpose: Publishes RC response when all windows closed; daily 00:00 Rome
// ──────────────────────────────────────────────────────────────────────────────
import { getFirestore, Timestamp } from "firebase-admin/firestore";
import { logger } from "firebase-functions";
import { onSchedule } from "firebase-functions/v2/scheduler";
import { DateTime } from "luxon";

import { SCHED_REGION_ROME, ROME_TZ } from "../common/config";
import { publishResponses } from "../utils/publish_responses";
import { isWorkingDay } from "../working_day";

const db = getFirestore();
const writer = db.bulkWriter();

export const committeeResponsePublisher = onSchedule(
  { region: SCHED_REGION_ROME, schedule: "0 0 * * *", timeZone: ROME_TZ },
  async (): Promise<void> => {
    const nowRome = DateTime.now().setZone(ROME_TZ);
    const nowTs = Timestamp.now();

    // working day check
    if (!isWorkingDay(nowRome)) {
      logger.info(
        `[committeeResponsePublisher] ${nowRome.toISO()} not a working day; skipping.`,
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
      logger.info("[committeeResponsePublisher] No qualifying enquiries.");
      return;
    }

    // loop through enquiries and lok for responses to publish
    let processed = 0;
    let published = 0;
    for (const enquiryDoc of enquiriesSnap.docs) {
      const publishResult = await publishResponses(
        writer,
        "committeeResponsePublisher",
        enquiryDoc,
        true,
      );
      processed += 1;
      published += publishResult.publishedNumber;
      if (publishResult.success == false) {
        logger.info(
          `[committeeResponsePublisher] Enquiry ${enquiryDoc.id} failed with reason: ${publishResult.failReason}.`,
        );
      }
    }
    await writer.close();
    logger.info(
      `[committeeResponsePublisher] Processed ${processed} enquiries; published ${published} committee responses.`,
    );
  },
);
