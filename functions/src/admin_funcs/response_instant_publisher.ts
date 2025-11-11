// ──────────────────────────────────────────────────────────────────────────────
// File: src/admin_funcs/response_instant_publisher.ts
// Purpose: Callable which publishes competitor responses for a given enquiry
// ──────────────────────────────────────────────────────────────────────────────
import { getFirestore } from "firebase-admin/firestore";
import { logger } from "firebase-functions";
import { onCall, HttpsError } from "firebase-functions/v2/https";

import { REGION, MEMORY, TIMEOUT_SECONDS } from "../common/config";
import { instantPublishPayload } from "../common/types";
import { publishResponses } from "../utils/publish_responses";

const db = getFirestore();

export const responseInstantPublisher = onCall(
  {
    region: REGION,
    cors: true,
    memory: MEMORY,
    timeoutSeconds: TIMEOUT_SECONDS,
    enforceAppCheck: true,
  },
  async (req) => {
    // 1) Auth
    if (!req.auth?.uid)
      throw new HttpsError("unauthenticated", "Sign in required.");
    const isAdmin = req.auth?.token.role === "admin";
    const isRC = req.auth?.token.team === "RC";
    if (!isAdmin && !isRC) {
      throw new HttpsError("permission-denied", "Admin/RC function only.");
    }
    // 2) Fetch enquiry
    const { enquiryId, rcResponse } = req.data as instantPublishPayload;
    const enquiryDoc = await db.collection("enquiries").doc(enquiryId).get();
    if (!enquiryDoc.exists) {
      logger.warn("[responseInstantPublisher] No matching enquiry.");
      return { ok: false, num_published: 0, reason: "no-enquiry-match" };
    }
    // 3) Search for and publish responses
    const writer = db.bulkWriter();
    const publishResult = await publishResponses(
      writer,
      "responseInstantPublisher",
      enquiryDoc,
      rcResponse,
    );
    await writer.close();
    if (publishResult.success == false) {
      logger.info(
        `[responseInstantPublisher] Enquiry ${enquiryDoc.id} failed with reason: ${publishResult.failReason}.`,
      );
    } else {
      logger.info(
        `[responseInstantPublisher] Published ${publishResult.publishedNumber} responses.`,
      );
    }
    return {
      ok: publishResult.success,
      num_published: publishResult.publishedNumber,
      reason: publishResult.failReason,
    };
  },
);
