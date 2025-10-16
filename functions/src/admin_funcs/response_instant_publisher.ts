// ──────────────────────────────────────────────────────────────────────────────
// File: src/admin_funcs/response_instant_publisher.ts
// Purpose: Callable which publishes competitor responses for a given enquiry
// ──────────────────────────────────────────────────────────────────────────────
import { FieldValue, getFirestore } from "firebase-admin/firestore";
import { logger } from "firebase-functions";
import { onCall, HttpsError } from "firebase-functions/v2/https";

import { REGION, MEMORY, TIMEOUT_SECONDS } from "../common/config";
import { instantPublishPayload } from "../common/types";
import { computeStageEnds } from "../utils/compute_stage_ends";
import {
  tokeniseAttachmentsIfAny,
  readAuthorTeam,
  queueDraftDelete,
  stageUpdatePayload,
} from "../utils/publish_helpers";

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
    const { enquiryID, rcResponse } = req.data as instantPublishPayload;
    const enquiryDoc = await db.collection("enquiries").doc(enquiryID).get();
    if (!enquiryDoc.exists) {
      logger.warn("[responseInstantPublisher] No matching enquiry.");
      return { ok: false, num_published: 0, reason: "no-enquiry-match" };
    }

    let totalResponsesPublished = 0;
    const writer = db.bulkWriter();
    const publishedAt = FieldValue.serverTimestamp();
    const enquiryData = enquiryDoc.data();
    const enquiryRef = enquiryDoc.ref;

    // 3) Get responses
    const unpublishedSnap = await enquiryRef
      .collection("responses")
      .where("isPublished", "==", false)
      .where("fromRC", "==", rcResponse)
      .get();
    // Copy docs into a mutable array
    const shuffled = [...unpublishedSnap.docs];
    // Guards
    if (shuffled.length == 0) {
      return { ok: false, num_published: 0, reason: "no-response" };
    } else if (rcResponse && shuffled.length > 1) {
      return { ok: false, num_published: 0, reason: "multiple-rc-responses" };
    }
    // Shuffle only if there’s more than one document
    if (shuffled.length > 1) {
      for (let i = shuffled.length - 1; i > 0; i--) {
        const j = Math.floor(Math.random() * (i + 1));
        [shuffled[i], shuffled[j]] = [shuffled[j], shuffled[i]];
      }
    }
    // 4) Edit response documents to publish them
    for (let i = 0; i < shuffled.length; i++) {
      writer.update(shuffled[i].ref, {
        isPublished: true,
        responseNumber: rcResponse ? 0 : i + 1,
        publishedAt,
      });
      await tokeniseAttachmentsIfAny(
        writer,
        shuffled[i].ref,
        shuffled[i].get("attachments"),
      );

      const team = await readAuthorTeam(shuffled[i].ref);
      if (!team) {
        logger.warn(
          `[responseInstantPublisher] No team found for ${shuffled[i].id}, skipping draft delete.`,
        );
      } else {
        queueDraftDelete(writer, team, shuffled[i].id);
      }
      totalResponsesPublished += 1;
    }

    // 5) advance stage for enquiry
    const stageLength = enquiryData!.stageLength ?? 4;
    const newStageEnds = rcResponse
      ? computeStageEnds(stageLength, { hour: 19, minute: 55 })
      : computeStageEnds(stageLength + 1, { hour: 11, minute: 55 });
    writer.update(enquiryRef, {
      teamsCanRespond: rcResponse, // depends on whose response is being published
      teamsCanComment: !rcResponse, // depends on whose response is being published
      ...(rcResponse && { roundNumber: FieldValue.increment(1) }),
      ...stageUpdatePayload(newStageEnds),
    });

    await writer.close();
    logger.info(
      `[responseInstantPublisher] Published ${totalResponsesPublished} responses.`,
    );
    return { ok: true, num_published: totalResponsesPublished };
  },
);
