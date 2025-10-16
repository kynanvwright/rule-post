// ──────────────────────────────────────────────────────────────────────────────
// File: src/posts/tx.ts
// Purpose: Pure Firestore transaction steps for createPost
// ──────────────────────────────────────────────────────────────────────────────
import {
  FieldValue,
  getFirestore,
  type Firestore,
  DocumentReference,
  DocumentData,
} from "firebase-admin/firestore";
import { HttpsError } from "firebase-functions/v2/https";

import { resolvePostColour } from "./colour";
import { isNotFoundError } from "../common/errors";

import type { AuthorInfo, CreatePostData, TxResult } from "../common/types";

export function postDocRef(
  db: Firestore,
  postType: CreatePostData["postType"],
  parentIds: string[],
) {
  if (postType === "enquiry") return db.collection("enquiries").doc();
  if (postType === "response")
    return db
      .collection("enquiries")
      .doc(parentIds[0])
      .collection("responses")
      .doc();
  return db
    .collection("enquiries")
    .doc(parentIds[0])
    .collection("responses")
    .doc(parentIds[1])
    .collection("comments")
    .doc();
}

export async function runCreatePostTx(
  db: Firestore,
  postType: CreatePostData["postType"],
  parentIds: string[],
  title: string,
  postText: string,
  docRef: DocumentReference<DocumentData>,
  stageLength: number,
  author: AuthorInfo,
): Promise<TxResult> {
  const postId = docRef.id;
  const postPath = docRef.path;

  await db.runTransaction(async (tx) => {
    const now = FieldValue.serverTimestamp();
    const fromRC = author.team === "RC";

    const publicDoc: Record<string, unknown> = {
      isPublished: false,
      fromRC,
    };
    if (title) publicDoc.title = title;
    if (postText) publicDoc.postText = postText;

    if (postType === "enquiry") {
      // Read/seed counter
      const countersRef = db.collection("app_data").doc("counters");
      const countersSnap = await tx.get(countersRef);
      const current = countersSnap.exists
        ? Number(countersSnap.get("enquiryNumber") ?? 0)
        : 0;

      // Guard against pre-counter docs or manual edits:
      // Find the highest enquiryNumber already stored on any enquiry.
      const maxSnap = await tx.get(
        db.collection("enquiries").orderBy("enquiryNumber", "desc").limit(1),
      );
      const maxFromDocs = maxSnap.empty
        ? 0
        : Number(maxSnap.docs[0].get("enquiryNumber") ?? 0);

      // Next = max(counter, existing max) + 1
      const next = Math.max(current, maxFromDocs) + 1;

      // Persist the counter advance; transactions will retry on contention
      tx.set(countersRef, { enquiryNumber: next }, { merge: true });

      Object.assign(publicDoc, {
        isOpen: true,
        enquiryNumber: next,
        roundNumber: 1,
        teamsCanRespond: true,
        teamsCanComment: false,
        stageLength: stageLength ?? 4,
      });

      // Public
      tx.set(docRef, publicDoc);

      // Private meta
      tx.set(docRef.collection("meta").doc("data"), {
        authorUid: author.uid,
        authorTeam: author.team,
        createdAt: now,
        teamColourMap: {}, // filled post-tx by your generator
      });
    } else {
      // Read enquiry
      const enquiryRef = db.collection("enquiries").doc(parentIds[0]);
      const enquirySnap = await tx.get(enquiryRef);
      if (!enquirySnap.exists) {
        throw new HttpsError(
          "failed-precondition",
          "No matching enquiry found.",
        );
      }

      if (enquirySnap.get("isOpen") !== true) {
        throw new HttpsError("failed-precondition", "Enquiry is closed.");
      }

      const roundNumber = Number(enquirySnap.get("roundNumber") || 0);
      const metaRef = enquiryRef.collection("meta").doc("data");
      const metaSnap = await tx.get(metaRef);
      if (!metaSnap.exists)
        throw new HttpsError("failed-precondition", "Enquiry meta not found.");
      const teamColourMap = (metaSnap.get("teamColourMap") || {}) as Record<
        string,
        string
      >;

      if (postType === "response") {
        if (
          author.team !== "RC" &&
          enquirySnap.get("teamsCanRespond") !== true
        ) {
          throw new HttpsError(
            "failed-precondition",
            "Competitors not permitted to respond at this time.",
          );
        }

        publicDoc.roundNumber =
          author.team === "RC" ? roundNumber + 1 : roundNumber;
        publicDoc.colour = await resolvePostColour(
          tx,
          db,
          author.team,
          teamColourMap,
        );

        // Uniqueness guard
        const guardRef = enquiryRef
          .collection("meta")
          .doc("response_guards")
          .collection("guards")
          .doc(`${author.team}_${roundNumber}`);
        try {
          tx.create(guardRef, {
            authorTeam: author.team,
            roundNumber,
            createdAt: now,
          });
        } catch (e: unknown) {
          if (isNotFoundError(e)) {
            throw new HttpsError(
              "already-exists",
              `Your team has already submitted a response for round ${roundNumber}.`,
            );
          }
          throw e; // rethrow anything unexpected
        }
      }

      if (postType === "comment") {
        if (
          author.team !== "RC" &&
          enquirySnap.get("teamsCanComment") !== true
        ) {
          throw new HttpsError(
            "failed-precondition",
            "Competitors not permitted to comment at this time.",
          );
        }
        const respRef = enquiryRef.collection("responses").doc(parentIds[1]);
        const respSnap = await tx.get(respRef);
        if (!respSnap.exists)
          throw new HttpsError("failed-precondition", "Response not found.");
        if (respSnap.get("fromRC") === true) {
          throw new HttpsError(
            "failed-precondition",
            "Comments can only be made on Competitor responses.",
          );
        }
        const respRound = Number(respSnap.get("roundNumber") || 0);
        if (respRound !== roundNumber) {
          throw new HttpsError(
            "failed-precondition",
            "Comments must target the latest round.",
          );
        }

        publicDoc.colour = await resolvePostColour(
          tx,
          db,
          author.team,
          teamColourMap,
        );
      }

      // Writes
      tx.set(docRef, publicDoc);
      tx.set(docRef.collection("meta").doc("data"), {
        authorUid: author.uid,
        authorTeam: author.team,
        createdAt: now,
      });
    }

    // Draft (per-team)
    const draftRef = db
      .collection("drafts")
      .doc("posts")
      .collection(author.team)
      .doc(postId);
    tx.set(draftRef, {
      createdAt: FieldValue.serverTimestamp(),
      postType,
      parentIds,
      authorUid: author.uid,
      authorTeam: author.team,
    });
  });

  // read-back enquiryNumber if needed (avoid extra read inside tx return)
  let enquiryNumber: number | undefined;
  if (postType === "enquiry") {
    const snap = await getFirestore().doc(postPath).get();
    enquiryNumber = Number(snap.get("enquiryNumber") ?? undefined);
  }

  return { postId, postPath, postType, enquiryNumber };
}
