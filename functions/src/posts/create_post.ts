// ──────────────────────────────────────────────────────────────────────────────
// File: src/posts/create_post.ts
// Purpose: Thin callable handler orchestrating validation, tx, storage moves
// ──────────────────────────────────────────────────────────────────────────────
import { getFirestore, DocumentReference } from "firebase-admin/firestore";
import { logger } from "firebase-functions";
import { onCall, HttpsError } from "firebase-functions/v2/https";

import { assignUniqueColoursForEnquiry } from "./colour"; // existing util from your codebase
import { moveValidatedAttachments } from "./storage";
import { runCreatePostTx, postDocRef } from "./tx";
import { coerceAndValidateInput, validateAttachments } from "./validate";
import { REGION, MEMORY, TIMEOUT_SECONDS } from "../common/config";
import { assert } from "../common/errors";

import type { CreatePostData } from "../common/types";

export const createPost = onCall<CreatePostData>(
  {
    region: REGION,
    cors: true,
    memory: MEMORY,
    timeoutSeconds: TIMEOUT_SECONDS,
    enforceAppCheck: true,
  },
  async (req) => {
    if (!req.auth?.uid)
      throw new HttpsError("unauthenticated", "Sign in required.");
    const authorUid = req.auth.uid;
    const authorTeam = String(req.auth.token.team ?? "").trim();
    if (!authorTeam)
      throw new HttpsError(
        "failed-precondition",
        "No team assigned to this user.",
      );

    const db = getFirestore();
    const data = coerceAndValidateInput((req.data ?? {}) as CreatePostData);
    logger.info("createPost start", {
      postType: data.postType,
      authorTeam,
      uid: authorUid,
    });

    // Pre-create doc ref to know postPath for storage placement
    const tempDocRef = postDocRef(db, data.postType, data.parentIds);
    // Log and type-check DocumentReference
    logger.info("postDocRef", {
      path: tempDocRef.path,
      id: (tempDocRef as DocumentReference).id,
    });

    if (
      !tempDocRef ||
      !(tempDocRef instanceof DocumentReference) ||
      typeof tempDocRef.id !== "string" ||
      !tempDocRef.id
    ) {
      throw new HttpsError(
        "internal",
        "postDocRef did not return a DocumentReference with an id",
      );
    }

    const postFolder = tempDocRef.path; // we will create same ref inside tx

    // Validate attachments (no writes yet)
    const validated = await validateAttachments({
      postType: data.postType,
      authorUid,
      postFolder,
      incoming: data.attachments,
    });

    // Firestore transaction
    logger.info("preTx paths", { pre: postFolder });
    const txRes = await runCreatePostTx(
      db,
      data.postType,
      data.parentIds,
      data.title,
      data.postText,
      tempDocRef,
      4,
      { uid: authorUid, team: authorTeam },
      data.closeEnquiryOnPublish,
      data.enquiryConclusion,
    );
    logger.info("postTx paths", {
      pre: postFolder,
      post: txRes.postPath,
    });

    assert(
      txRes.postPath === postFolder,
      "Doc path mismatch between pre-ref and tx.",
    );

    // After tx: move files then patch doc with attachments
    if (validated.length > 0) {
      const finalised = await moveValidatedAttachments({
        postFolder,
        incoming: data.attachments,
        validated,
      });
      await db.doc(txRes.postPath).update({ attachments: finalised });
    }

    // Post-step: populate team colours for new enquiries using your existing util
    if (txRes.postType === "enquiry") {
      try {
        const colourMap = await assignUniqueColoursForEnquiry(txRes.postId);
        await db
          .doc(`${txRes.postPath}/meta/data`)
          .set({ teamColourMap: colourMap ?? {} }, { merge: true });
      } catch (e) {
        // Non-fatal: log and continue (UI can still render; colours apply on next operations)
        logger.warn("assignUniqueColoursForEnquiry failed", {
          enquiryId: txRes.postId,
          error: String(e),
        });
      }
    }

    return {
      id: txRes.postId,
      path: txRes.postPath,
      enquiryNumber: txRes.enquiryNumber,
    };
  },
);
