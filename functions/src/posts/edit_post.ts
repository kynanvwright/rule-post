// ──────────────────────────────────────────────────────────────────────────────
// File: src/posts/edit_post.ts
// Purpose: Edit an existing post draft
// ──────────────────────────────────────────────────────────────────────────────
import { FieldValue, getFirestore } from "firebase-admin/firestore";
import { logger } from "firebase-functions";
import { onCall, HttpsError } from "firebase-functions/v2/https";

import { moveValidatedAttachments } from "./storage";
import { runEditPostTx } from "./tx";
import { coerceAndValidateInput, validateAttachments } from "./validate";
import { REGION, MEMORY, TIMEOUT_SECONDS } from "../common/config";
import { assert } from "../common/errors";

import type { CreatePostData, EditPostData } from "../common/types";

export const editPost = onCall<EditPostData>(
  {
    region: REGION,
    cors: true,
    memory: MEMORY,
    timeoutSeconds: TIMEOUT_SECONDS,
    enforceAppCheck: true,
  },
  async (req) => {
    // check that function should run for this user and post
    if (!req.auth?.uid)
      throw new HttpsError("unauthenticated", "Sign in required.");
    const authorUid = req.auth.uid;
    const authorTeam = String(req.auth.token.team ?? "").trim();
    if (!authorTeam)
      throw new HttpsError(
        "failed-precondition",
        "No team assigned to this user.",
      );
    // extract and validate data
    const db = getFirestore();
    const postId = req.data.postId;
    const editAttachments = req.data.editAttachments;
    const data = coerceAndValidateInput((req.data ?? {}) as CreatePostData);
    logger.info("editPost start", {
      postType: data.postType,
      authorTeam,
      authorUid: authorUid,
      postId: postId,
    });

    // get document reference and folder, no need to create new
    const draftCollectionRef =
      data.postType == "enquiry"
        ? db.collection("enquiries")
        : data.postType == "response"
          ? db
              .collection("enquiries")
              .doc(data.parentIds[0])
              .collection("responses")
          : db
              .collection("enquiries")
              .doc(data.parentIds[0])
              .collection("responses")
              .doc(data.parentIds[1])
              .collection("comments");
    const draftDocRef = draftCollectionRef.doc(postId);
    const postFolder = draftDocRef.path;

    // check that data is permitted to be edited
    const snap = await draftDocRef.get();
    if (!snap.exists) {
      throw new HttpsError("failed-precondition", "Document does not exist.");
    } else {
      const isPublished = snap.get("isPublished");
      if (isPublished) {
        throw new HttpsError(
          "failed-precondition",
          "Only unpublished drafts may be edited.",
        );
      }
    }

    // Update fields with new values
    logger.info("preTx paths", { pre: postFolder });
    const txRes = await runEditPostTx(
      db,
      data.postType,
      data.parentIds,
      data.title,
      data.postText,
      draftDocRef,
      { uid: authorUid, team: authorTeam },
    );
    logger.info("postTx paths", {
      pre: postFolder,
      post: txRes.postPath,
    });

    assert(
      txRes.postPath === postFolder,
      "Doc path mismatch between pre-ref and tx.",
    );

    // Attachment check and possible update
    // if no attachments in update, remove attachment field if it exists
    // if no attachments in old version, skip comparison and just load in
    // if attachments in both, run hash comparison and leave alone if they match
    if (editAttachments["add"] || editAttachments["remove"]) {
      logger.info("editAttachments", {
        add: editAttachments["remove"],
        remove: editAttachments["remove"],
        removeList: editAttachments["removeList"],
      });
      // Validate attachments (no writes yet)
      const validated = await validateAttachments({
        postType: data.postType,
        authorUid,
        postFolder,
        incoming: data.attachments,
      });
      if (validated.length > 0) {
        const finalised = await moveValidatedAttachments({
          postFolder,
          incoming: data.attachments,
          validated,
        });
        const existing = snap.data()?.attachments ?? [];
        const filteredExisting = existing.filter(
          (a: string) =>
            !editAttachments["removeList"].some((r: string) => r === a),
        );
        const merged = [...filteredExisting, ...finalised];
        await db.doc(txRes.postPath).update({ attachments: merged });
        // await db.doc(txRes.postPath).update({ attachments: finalised });
      } else {
        await db.doc(txRes.postPath).update({ attachments: FieldValue.delete });
      }
    }

    return {
      id: txRes.postId,
      path: txRes.postPath,
      enquiryNumber: txRes.enquiryNumber,
    };
  },
);
