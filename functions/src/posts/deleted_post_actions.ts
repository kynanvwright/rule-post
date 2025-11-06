// ──────────────────────────────────────────────────────────────────────────────
// File: src/posts/deleted_post_actions.ts
// Purpose: Thin callable handler orchestrating validation, tx, storage moves
// ──────────────────────────────────────────────────────────────────────────────
import { getStorage } from "firebase-admin/storage";
import { onDocumentDeleted } from "firebase-functions/v2/firestore";

import { REGION } from "../common/config";
import { db } from "../common/db";
import { deleteUnreadForAllUsers } from '../utils/unread_post_generator';

async function getMaxValue(
  collectionPath: string,
  field: string,
): Promise<number | null> {
  console.log("🧭 getMaxValue called with", collectionPath, field);
  if (!collectionPath) {
    console.error("❌ Invalid collectionPath", collectionPath);
    throw new Error("collectionPath must be non-empty");
  }
  const snap = await db
    .collection(collectionPath) // can be nested
    .orderBy(field, "desc")
    .limit(1)
    .get();

  return snap.empty ? null : snap.docs[0].get(field);
}

/** Shared cleanup so logic stays DRY */
async function handleDeletion(args: {
  kind: "enquiry" | "response" | "comment";
  enquiryId: string;
  responseId?: string;
  commentId?: string;
  data: FirebaseFirestore.DocumentData | undefined; // pre-delete snapshot data
}) {
  const { kind, enquiryId, responseId, commentId, data } = args;

  if (kind === "enquiry") {
    // Delete drafts if any
    deleteDraftDoc(enquiryId);
    // Delete publishEvents if any
    const q = db
      .collection("publishEvents")
      .where("enquiryId", "==", enquiryId)
      .where("kind", "==", "enquiry")
      .limit(1); // since we expect only one
    const snap = await q.get();
    if (!snap.empty) await snap.docs[0].ref.delete();
    // If enquiryNumber is app maximum, reduce app_data counter
    const counterRef = db.collection("app_data").doc("counters");
    const maxEnquiryNumberCounter = (await counterRef.get()).get(
      "enquiryNumber",
    );
    (await db.collection("app_data").doc("counters").get()).get(
      "enquiryNumber",
    );
    if (
      args.data?.enquiryNumber != null &&
      args.data?.enquiryNumber == maxEnquiryNumberCounter
    ) {
      const maxEnquiryNumber = await getMaxValue("enquiries", "enquiryNumber");
      await counterRef.update({ enquiryNumber: maxEnquiryNumber });
    }
    // delete files attached to post
    const path = `enquiries/${enquiryId}/`;
    deleteFolder(path);
    // delete unreadPost records
    deleteUnreadForAllUsers(enquiryId)
  } else if (kind === "response" && responseId) {
    deleteDraftDoc(responseId);
    // Delete publishEvents if any
    const q = db
      .collection("publishEvents")
      .where("responseId", "==", responseId)
      .where("kind", "==", "response")
      .limit(1); // since we expect only one
    const snap = await q.get();
    if (!snap.empty) await snap.docs[0].ref.delete();
    // delete relevant guards on response authors
    const guardPath = `enquiries/${enquiryId}/meta/response_guards/guards/`;
    const guardQuery = db
      .collection(guardPath)
      .where("latestResponseId", "==", responseId)
      .limit(1); // since we expect only one
    const guardSnap = await guardQuery.get();
    if (!guardSnap.empty) await guardSnap.docs[0].ref.delete();
    // delete files attached to post
    const path = `enquiries/${enquiryId}/responses/${responseId}/`;
    deleteFolder(path);
    // delete unreadPost records
    deleteUnreadForAllUsers(responseId)
    // Add some logic to deal with response numbering
  } else if (kind === "comment" && commentId) {
    // Delete drafts if any
    deleteDraftDoc(commentId);
    // Delete publishEvents if any
    const q = db
      .collection("publishEvents")
      .where("commentId", "==", commentId)
      .where("kind", "==", "comment")
      .limit(1); // since we expect only one
    const snap = await q.get();
    if (!snap.empty) await snap.docs[0].ref.delete();
    // delete files attached to post
    const path = `enquiries/${enquiryId}/responses/${responseId}/comments/${commentId}/`;
    deleteFolder(path);
    // delete unreadPost records
    deleteUnreadForAllUsers(commentId)
    // Add some logic to deal with comment numbering
  }

  console.log("Deleted", { kind, enquiryId, responseId, commentId, data });
}

/** 1) enquiries/{enquiryId} */
export const onEnquiryDeleted = onDocumentDeleted(
  {
    region: REGION,
    document: "enquiries/{enquiryId}",
    // retry: true,
  },
  async (event) => {
    const { enquiryId } = event.params as { enquiryId: string };
    const data = event.data?.data(); // pre-delete snapshot data

    await handleDeletion({ kind: "enquiry", enquiryId, data });
  },
);

/** 2) enquiries/{enquiryId}/responses/{responseId} */
export const onResponseDeleted = onDocumentDeleted(
  {
    region: REGION,
    document: "enquiries/{enquiryId}/responses/{responseId}",
  },
  async (event) => {
    const { enquiryId, responseId } = event.params as {
      enquiryId: string;
      responseId: string;
    };
    const data = event.data?.data();
    await handleDeletion({
      kind: "response",
      enquiryId,
      responseId,
      data,
    });
  },
);

/** 3) enquiries/{enquiryId}/responses/{responseId}/comments/{commentId} */
export const onCommentDeleted = onDocumentDeleted(
  {
    region: REGION,
    document:
      "enquiries/{enquiryId}/responses/{responseId}/comments/{commentId}",
  },
  async (event) => {
    const { enquiryId, responseId, commentId } = event.params as {
      enquiryId: string;
      responseId: string;
      commentId: string;
    };
    const data = event.data?.data();
    await handleDeletion({
      kind: "comment",
      enquiryId,
      responseId,
      commentId,
      data,
    });
  },
);

async function deleteDraftDoc(docId: string) {
  const postsRef = db.collection("drafts").doc("posts");
  const subcollections = await postsRef.listCollections();
  for (const teamCol of subcollections) {
    const docRef = teamCol.doc(docId);
    const docSnap = await docRef.get();
    if (docSnap.exists) {
      await docRef.delete();
    }
  }
}

/**
 * Deletes all files under a given folder prefix in Firebase Storage.
 * Example: deleteFolder("enquiries/123/responses/456")
 */
async function deleteFolder(prefix: string): Promise<void> {
  if (!prefix) return; // safety guard

  const bucket = getStorage().bucket();

  try {
    const [files] = await bucket.getFiles({ prefix });

    if (files.length === 0) {
      console.log(`📂 Folder empty or already deleted: ${prefix}`);
      return;
    }

    await Promise.all(
      files.map((file) =>
        file.delete({ ignoreNotFound: true }).catch((err) => {
          console.error(`❌ Failed to delete ${file.name}:`, err.message);
        }),
      ),
    );

    console.log(`🗑️ Deleted ${files.length} file(s) under ${prefix}`);
  } catch (err) {
    console.error(
      `❌ Error deleting folder ${prefix}:`,
      (err as Error).message,
    );
  }
}
