// ──────────────────────────────────────────────────────────────────────────────
// File: src/posts/delete_post.ts
// Purpose: Delete an unpublished post draft
// ──────────────────────────────────────────────────────────────────────────────
import { getFirestore } from "firebase-admin/firestore";
import { logger } from "firebase-functions";
import { onCall, HttpsError } from "firebase-functions/v2/https";

import { REGION, MEMORY, TIMEOUT_SECONDS } from "../common/config";

import type { DeletePostData } from "../common/types";

export const deletePost = onCall<DeletePostData>(
  {
    region: REGION,
    cors: true,
    memory: MEMORY,
    timeoutSeconds: TIMEOUT_SECONDS,
    enforceAppCheck: true,
  },
  async (req) => {
    // Check that function should run for this user
    if (!req.auth?.uid)
      throw new HttpsError("unauthenticated", "Sign in required.");
    const authorUid = req.auth.uid;
    const authorTeam = String(req.auth.token.team ?? "").trim();
    if (!authorTeam)
      throw new HttpsError(
        "failed-precondition",
        "No team assigned to this user.",
      );

    // Extract and validate data
    const db = getFirestore();
    const postType = req.data.postType;
    const postId = req.data.postId;
    const parentIds = req.data.parentIds ?? [];

    logger.info("deletePost start", {
      postType,
      authorTeam,
      authorUid,
      postId,
    });

    // Validate postType
    if (!["enquiry", "response", "comment"].includes(postType)) {
      throw new HttpsError("invalid-argument", "Invalid post type.");
    }

    // Get document reference
    const draftCollectionRef =
      postType === "enquiry"
        ? db.collection("enquiries")
        : postType === "response"
          ? db.collection("enquiries").doc(parentIds[0]).collection("responses")
          : db
              .collection("enquiries")
              .doc(parentIds[0])
              .collection("responses")
              .doc(parentIds[1])
              .collection("comments");

    const draftDocRef = draftCollectionRef.doc(postId);
    const postFolder = draftDocRef.path;

    // Check that document exists and is not published
    const snap = await draftDocRef.get();
    if (!snap.exists) {
      throw new HttpsError("failed-precondition", "Document does not exist.");
    }

    const isPublished = snap.get("isPublished");
    if (isPublished) {
      throw new HttpsError(
        "failed-precondition",
        "Only unpublished drafts may be deleted.",
      );
    }

    // Delete the document
    await draftDocRef.delete();
    logger.info("deletePost document deleted", {
      postFolder,
      postId,
    });

    logger.info("deletePost completed successfully", {
      postFolder,
      postId,
    });

    return {
      id: postId,
      path: postFolder,
    };
  },
);
