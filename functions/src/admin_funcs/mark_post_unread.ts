// ──────────────────────────────────────────────────────────────────────────────
// File: src/admin_funcs/mark_post_unread.ts
// Purpose: Mark a post as unread for the user, for testing
// ──────────────────────────────────────────────────────────────────────────────
import { getFirestore } from "firebase-admin/firestore";
import { logger } from "firebase-functions";
import { onCall, HttpsError } from "firebase-functions/v2/https";

import { REGION, MEMORY, TIMEOUT_SECONDS } from "../common/config";
import { UnreadPostPayload } from "../common/types";
import { createUnreadForAllUsers } from "../utils/unread_post_generator";

const db = getFirestore();

export const markPostUnread = onCall(
  {
    region: REGION,
    cors: true,
    memory: MEMORY,
    timeoutSeconds: TIMEOUT_SECONDS,
    enforceAppCheck: true,
  },
  async (req) => {
    // 1) AuthZ
    const callerUid = req.auth?.uid;
    if (!callerUid) {
      throw new HttpsError("unauthenticated", "You must be signed in.");
    }
    const isAdmin = req.auth?.token.role === "admin";
    const isRC = req.auth?.token.team === "RC";
    if (!isAdmin && !isRC) {
      throw new HttpsError("permission-denied", "Admin/RC function only.");
    }

    // 2) Unpack ids and write conditional on inputs
    const { enquiryId, responseId, commentId } = req.data as UnreadPostPayload;
    logger.info("[markPostUnread] Id payload:", {
      enquiryId: enquiryId,
      responseId: responseId,
      commentId: commentId,
    });
    const writer = db.bulkWriter();

    // 2a) enquiry-level write
    const enquirySnap = await db.collection("enquiries").doc(enquiryId).get();
    if (!enquirySnap.exists) {
      throw new Error(`[markPostUnread] Enquiry not found: ${enquiryId}`);
    }
    const enquiryData = enquirySnap.data() as {
      enquiryNumber?: number;
      title?: string;
    };
    const enquiryAlias =
      enquiryData.enquiryNumber != null && enquiryData.title != null
        ? `RE #${enquiryData.enquiryNumber} - ${enquiryData.title}`
        : "RE #x - x";
    const enquiryIsTarget = responseId == null;
    await createUnreadForAllUsers(
      writer,
      "enquiry",
      enquiryAlias,
      enquiryId,
      enquiryIsTarget,
      {},
      { userId: callerUid },
    );
    // 2b) response-level write
    if (responseId != null) {
      const responseSnap = await db
        .collection("enquiries")
        .doc(enquiryId)
        .collection("responses")
        .doc(responseId)
        .get();
      if (!responseSnap.exists) {
        throw new Error(
          `[markPostUnread] Response not found: ${enquiryId}/${responseId}`,
        );
      }
      const responseData = responseSnap.data() as {
        roundNumber?: number;
        responseNumber?: number;
      };
      const responseAlias =
        responseData.roundNumber != null && responseData.responseNumber != null
          ? `Response ${responseData.roundNumber}.${responseData.responseNumber}`
          : "Response x.x";
      const responseIsTarget = commentId == null;
      await createUnreadForAllUsers(
        writer,
        "response",
        responseAlias,
        responseId,
        responseIsTarget,
        {
          parentId: enquiryId,
        },
        { userId: callerUid },
      );
    }
    // 2c) comment-level write
    if (commentId != null && responseId != null) {
      const commentSnap = await db
        .collection("enquiries")
        .doc(enquiryId)
        .collection("responses")
        .doc(responseId)
        .collection("comments")
        .doc(commentId)
        .get();
      if (!commentSnap.exists) {
        throw new Error(
          `[markPostUnread] Comment not found: ${enquiryId}/${responseId}/${commentId}`,
        );
      }
      const commentData = commentSnap.data() as { commentNumber?: number };
      const alias =
        commentData.commentNumber != null
          ? `Comment #${commentData.commentNumber}`
          : "Comment #x";
      await createUnreadForAllUsers(
        writer,
        "comment",
        alias,
        commentId,
        true,
        {
          parentId: responseId,
          grandparentId: enquiryId,
        },
        { userId: callerUid },
      );
    }

    return { ok: true };
  },
);
