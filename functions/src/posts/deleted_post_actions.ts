// ──────────────────────────────────────────────────────────────────────────────
// File: src/posts/deleted_post_actions.ts
// Purpose: Thin callable handler orchestrating validation, tx, storage moves
// ──────────────────────────────────────────────────────────────────────────────
import { onDocumentDeleted } from "firebase-functions/v2/firestore";

import { REGION } from "../common/config";
import { db } from "../common/db";

async function getMaxValue(
  collectionPath: string,
  field: string,
): Promise<number | null> {
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
  team: string;
}) {
  const { kind, enquiryId, responseId, commentId, data } = args;

  if (kind === "enquiry") {
    // Delete drafts if any
    db.collection("drafts")
      .doc("posts")
      .collection(args.team)
      .doc(enquiryId)
      .delete();
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
  } else if (kind === "response" && responseId) {
    // Delete drafts if any
    db.collection("drafts")
      .doc("posts")
      .collection(args.team)
      .doc(responseId)
      .delete();
    // Delete publishEvents if any
    const q = db
      .collection("publishEvents")
      .where("responseId", "==", responseId)
      .where("kind", "==", "response")
      .limit(1); // since we expect only one
    const snap = await q.get();
    if (!snap.empty) await snap.docs[0].ref.delete();
    // Add some logic to deal with response numbering
  } else if (kind === "comment" && commentId) {
    // Delete drafts if any
    db.collection("drafts")
      .doc("posts")
      .collection(args.team)
      .doc(commentId)
      .delete();
    // Delete publishEvents if any
    const q = db
      .collection("publishEvents")
      .where("commentId", "==", commentId)
      .where("kind", "==", "comment")
      .limit(1); // since we expect only one
    const snap = await q.get();
    if (!snap.empty) await snap.docs[0].ref.delete();
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
    const team = (
      await db
        .collection("enquiries")
        .doc(enquiryId)
        .collection("meta")
        .doc("data")
        .get()
    ).get("authorTeam");
    await handleDeletion({ kind: "enquiry", enquiryId, data, team });
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
    const team = (
      await db
        .collection("enquiries")
        .doc(enquiryId)
        .collection("responses")
        .doc(responseId)
        .collection("meta")
        .doc("data")
        .get()
    ).get("authorTeam");
    await handleDeletion({
      kind: "response",
      enquiryId,
      responseId,
      data,
      team,
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
    const team = (
      await db
        .collection("enquiries")
        .doc(enquiryId)
        .collection("responses")
        .doc(responseId)
        .collection("comments")
        .doc(commentId)
        .collection("meta")
        .doc("data")
        .get()
    ).get("authorTeam");
    await handleDeletion({
      kind: "comment",
      enquiryId,
      responseId,
      commentId,
      data,
      team,
    });
  },
);
