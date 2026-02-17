// ──────────────────────────────────────────────────────────────────────────────
// File: src/scheduled_funcs/team_response_publisher.ts
// Purpose: Publishes competitor responses after stage end; nightly 20:00 Rome
// ──────────────────────────────────────────────────────────────────────────────
import { getFirestore, Timestamp } from "firebase-admin/firestore";
import { logger } from "firebase-functions";

import { publishResponses } from "../utils/publish_responses";

const db = getFirestore();

/** Helper function extracted for use by orchestrator */
export async function doTeamResponsePublish(): Promise<void> {
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
    logger.info("[doTeamResponsePublish] No qualifying enquiries.");
    return;
  }

  // loop through enquiries and look for responses to publish
  let processed = 0;
  let published = 0;
  const writer = db.bulkWriter();
  for (const enquiryDoc of enquiriesSnap.docs) {
    const publishResult = await publishResponses(
      writer,
      "doTeamResponsePublish",
      enquiryDoc,
      false,
    );
    processed += 1;
    published += publishResult.publishedNumber;
    if (publishResult.success == false) {
      logger.info(
        `[doTeamResponsePublish] Enquiry ${enquiryDoc.id} failed with reason: ${publishResult.failReason}.`,
      );
    }
  }
  await writer.close();
  logger.info(
    `[doTeamResponsePublish] Processed ${processed} enquiries; published ${published} responses.`,
  );
}

// ✅ Note: teamResponsePublisher is no longer exported directly.
// It is called by the orchestrator (orchestrate2000).
// Legacy export commented out:
/*
export const teamResponsePublisher = onSchedule(
  {
    region: SCHED_REGION_ROME,
    schedule: "0 20 * * *",
    timeZone: ROME_TZ,
    timeoutSeconds: TIMEOUT_SECONDS,
  },
  async (): Promise<void> => {
    await doTeamResponsePublish();
  },
);
*/
