// ──────────────────────────────────────────────────────────────────────────────
// File: src/posts/edit_post.ts
// Purpose: Edit an existing post draft
// ──────────────────────────────────────────────────────────────────────────────
import { getFirestore } from "firebase-admin/firestore";
import { getStorage } from "firebase-admin/storage";
import { logger } from "firebase-functions";
import { onCall, HttpsError } from "firebase-functions/v2/https";

import { moveValidatedAttachments } from "./storage";
import { runEditPostTx } from "./tx";
import { coerceAndValidateInput, validateAttachments } from "./validate";
import { REGION, MEMORY, TIMEOUT_SECONDS } from "../common/config";
import { assert } from "../common/errors";

import type {
  CreatePostData,
  EditPostData,
  FinalisedAttachment,
} from "../common/types";

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
    logger.info("editAttachments", {
      add: editAttachments["add"],
      remove: editAttachments["remove"],
      removeList: editAttachments["removeList"],
    });
    if (editAttachments["add"] || editAttachments["remove"]) {
      // Validate attachments (no writes yet)
      let finalised: FinalisedAttachment[] = [];
      if (editAttachments["add"]) {
        const validated = await validateAttachments({
          postType: data.postType,
          authorUid,
          postFolder,
          incoming: data.attachments,
        });
        if (validated.length > 0) {
          finalised = await moveValidatedAttachments({
            postFolder,
            incoming: data.attachments,
            validated,
          });
        }
      }
      const existing = snap.data()?.attachments ?? [];
      const filteredExisting = editAttachments["remove"]
        ? existing.filter(
            (a: FinalisedAttachment) =>
              !editAttachments["removeList"].includes(a.path),
          )
        : existing;
      const merged = [...filteredExisting, ...finalised];
      await db.doc(txRes.postPath).update({ attachments: merged });
      if (editAttachments["remove"]) {
        const bucket = getStorage().bucket();
        await Promise.all(
          editAttachments["removeList"].map(async (path) => {
            try {
              await bucket.file(path).delete();
              console.log(`Deleted: ${path}`);
            } catch (error) {
              console.error(`Error deleting ${path}:`, error);
            }
          }),
        );
      }
    }

    return {
      id: txRes.postId,
      path: txRes.postPath,
      enquiryNumber: txRes.enquiryNumber,
    };
  },
);
