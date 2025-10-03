import { getFirestore, FieldValue, Timestamp } from "firebase-admin/firestore";
import { onCall, HttpsError } from "firebase-functions/v2/https";

import { computeStageEnds } from "./publishing_and_permissions";

const db = getFirestore();

type publishPayload = {
  enquiryID: string;
  responseID?: string;
};

export const committeeResponseInstantPublisher = onCall(
  { cors: true, enforceAppCheck: true },
  async (req) => {
    // 1) Check user is logged in and admin
    const callerUid = req.auth?.uid;
    if (!callerUid)
      throw new HttpsError("unauthenticated", "You must be signed in.");
    const isAdmin = req.auth?.token.role == "admin";
    const isRC = req.auth?.token.team == "RC";
    if (!isAdmin && !isRC) {
      throw new HttpsError("permission-denied", "Admin/RC function only.");
    }

    // 2) Get enquiry and response from Firestore
    const { enquiryID, responseID } = req.data as publishPayload;
    const enquiryDoc = await db.collection("enquiries").doc(enquiryID).get();
    if (!enquiryDoc.exists) {
      console.log("[committeeResponseInstantPublisher] No matching enquiry.");
      return;
    }
    const enquiryRef = enquiryDoc.ref;
    let responseRef: FirebaseFirestore.DocumentReference;
    let responseSnap: FirebaseFirestore.DocumentSnapshot;

    if (responseID) {
      // Path: explicit response
      responseRef = enquiryRef.collection("responses").doc(responseID);
      responseSnap = await responseRef.get();

      if (!responseSnap.exists) {
        console.log(
          "[committeeResponseInstantPublisher] No matching response.",
        );
        return;
      }
    } else {
      // Path: find latest unpublished RC response
      const committeeSnap = await enquiryRef
        .collection("responses")
        .where("fromRC", "==", true)
        .where("isPublished", "==", false)
        .get();

      if (committeeSnap.empty) {
        console.log(
          "[committeeResponseInstantPublisher] No unpublished RC responses.",
        );
        return;
      }
      if (committeeSnap.size !== 1) {
        console.log(
          "[committeeResponseInstantPublisher] Too many unpublished RC responses.",
        );
        return;
      }

      // docs[0] is already a QueryDocumentSnapshot (a kind of DocumentSnapshot)
      const doc0 = committeeSnap.docs[0];
      responseRef = doc0.ref;
      responseSnap = doc0; // already a snapshot; no extra get() needed
    }

    try {
      await db.runTransaction(async (tx) => {
        const e = enquiryDoc.data() || {};
        const roundNumber = e.roundNumber as number | undefined;

        if (typeof roundNumber !== "number") {
          return;
        }

        const stillOpen =
          e.isOpen === true &&
          e.isPublished === true &&
          e.teamsCanRespond === false;

        if (!stillOpen) {
          console.log(
            "[committeeResponseInstantPublisher] Enquiry is not at correct stage for this action.",
          );
          return;
        }

        tx.update(responseRef, {
          isPublished: true,
          roundNumber: roundNumber + 1,
          responseNumber: 0,
        });

        const nextStageEnds = computeStageEnds(4, { hour: 19, minute: 55 });

        tx.update(enquiryRef, {
          roundNumber: FieldValue.increment(1),
          teamsCanRespond: true,
          teamsCanComment: false,
          stageEnds: Timestamp.fromDate(nextStageEnds),
        });
      });
    } catch (err) {
      console.error(
        "[committeeResponseInstantPublisher] Transaction failed for " +
          `enquiry ${enquiryID}:`,
        err,
      );
    }
  },
);
