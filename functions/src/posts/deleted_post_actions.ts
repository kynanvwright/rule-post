// ──────────────────────────────────────────────────────────────────────────────
// File: src/posts/deleted_post_actions.ts
// Purpose: Thin callable handler orchestrating validation, tx, storage moves
// ──────────────────────────────────────────────────────────────────────────────
import { getStorage } from "firebase-admin/storage";
import { onDocumentDeleted } from "firebase-functions/v2/firestore";

import { REGION } from "../common/config";
import { db } from "../common/db";
import { deleteUnreadForAllUsers } from "../utils/unread_post_generator";

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
    // Delete draft record of the post
    await deleteDraftDoc(enquiryId);

    // Delete ALL publishEvents for this enquiry/kind
    const eventsSnap = await db
      .collection("publishEvents")
      .where("enquiryId", "==", enquiryId)
      .where("kind", "==", "enquiry")
      .get();
    await Promise.all(eventsSnap.docs.map((d) => d.ref.delete()));

    // Recompute max enquiryNumber (robust against races & drift)
    const maxSnap = await db
      .collection("enquiries")
      .orderBy("enquiryNumber", "desc")
      .limit(1)
      .get();
    const maxEnquiryNumber = maxSnap.empty
      ? 0 // or null if you prefer
      : (maxSnap.docs[0].get("enquiryNumber") as number);

    await db
      .collection("app_data")
      .doc("counters")
      .set({ enquiryNumber: maxEnquiryNumber }, { merge: true });

    // delete files attached to post
    await deleteFolder(`enquiries/${enquiryId}/`);

    // delete unreadPost records
    await deleteUnreadForAllUsers(enquiryId, "enquiry");
  } else if (kind === "response" && responseId) {
    // Delete draft record of the post
    await deleteDraftDoc(responseId);

    // Delete publishEvents if any
    const q = db
      .collection("publishEvents")
      .where("responseId", "==", responseId)
      .where("kind", "==", "response")
      .limit(1); // since we expect only one
    const snap = await q.get();
    if (!snap.empty) await snap.docs[0].ref.delete();

    // Delete response guard by primary key instead of latestResponseId field.
    // This is safer: the guard's natural ID is ${authorTeam}_${roundNumber}.
    // We need to extract these from the deleted response document.
    try {
      const responseRef = db
        .collection("enquiries")
        .doc(enquiryId)
        .collection("responses")
        .doc(responseId);
      
      // Try to extract roundNumber and authorTeam from the snapshot if available
      let roundNumber: number | undefined;
      let authorTeam: string | undefined;

      if (data) {
        // Use pre-delete snapshot data passed from the event
        roundNumber = Number(data.roundNumber ?? 0);
        authorTeam = data.fromRC ? "RC" : undefined; // public doc doesn't have team
      }

      // If we couldn't get authorTeam from public doc, read the meta/data
      if (!authorTeam) {
        try {
          const metaSnap = await responseRef.collection("meta").doc("data").get();
          if (metaSnap.exists) {
            authorTeam = metaSnap.get("authorTeam");
            if (!roundNumber) {
              roundNumber = Number(data?.roundNumber ?? 0);
            }
          }
        } catch (metaError) {
          console.warn("Failed to read response meta during guard cleanup", {
            enquiryId,
            responseId,
            error: String(metaError),
          });
        }
      }

      // Delete guard by primary key if we have the necessary info
      if (authorTeam && roundNumber !== undefined) {
        const guardId = `${authorTeam}_${roundNumber}`;
        const guardRef = db
          .collection(`enquiries/${enquiryId}/meta/response_guards/guards`)
          .doc(guardId);
        const guardSnap = await guardRef.get();
        if (guardSnap.exists) {
          await guardRef.delete();
          console.log("✅ Guard deleted by primary key", {
            enquiryId,
            responseId,
            guardId,
          });
        } else {
          console.warn("Guard not found (may already be deleted)", {
            enquiryId,
            responseId,
            guardId,
          });
        }
      } else {
        console.error(
          "Cannot delete guard: missing roundNumber or authorTeam",
          {
            enquiryId,
            responseId,
            authorTeam,
            roundNumber,
          },
        );
      }
    } catch (guardError) {
      console.error("Unexpected error during guard cleanup", {
        enquiryId,
        responseId,
        error: String(guardError),
      });
      // Don't rethrow; guard cleanup failure should not block other cleanups
    }

    // delete files attached to post
    const path = `enquiries/${enquiryId}/responses/${responseId}/`;
    await deleteFolder(path);

    // delete unreadPost records
    await deleteUnreadForAllUsers(responseId, "response");
    // Add some logic to deal with response numbering
  } else if (kind === "comment" && commentId) {
    // Delete draft record of the post
    await deleteDraftDoc(commentId);

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
    await deleteFolder(path);

    // delete unreadPost records
    await deleteUnreadForAllUsers(commentId, "comment");
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
