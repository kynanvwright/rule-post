import { getFirestore, FieldValue, Timestamp } from "firebase-admin/firestore";
// import { logger } from "firebase-functions";
import { onCall, HttpsError } from "firebase-functions/v2/https";

import { Attachment, publishAttachments } from "./make_attachments_public";
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

    // inside your callable/handler
    const publishedAt = FieldValue.serverTimestamp();

    try {
      // 1) Run the transaction and return info needed for post-tx work
      const txResult = await db.runTransaction(async (tx) => {
        // --- READS FIRST ---------------------------------------------------------
        const enquirySnap = await tx.get(enquiryRef);
        if (!enquirySnap.exists) {
          throw new Error(`Enquiry ${enquiryRef.id} not found`);
        }
        const e = enquirySnap.data() ?? {};
        const roundNumber =
          typeof e.roundNumber === "number" ? e.roundNumber : undefined;

        if (roundNumber === undefined) {
          // Nothing to do; return consistent shape for client
          return {
            ok: false,
            reason: "Missing roundNumber",
            attachments: [] as Attachment[],
            team: undefined as string | undefined,
          };
        }

        const stillOpen =
          e.isOpen === true &&
          e.isPublished === true &&
          e.teamsCanRespond === false;

        if (!stillOpen) {
          console.log(
            "[committeeResponseInstantPublisher] Enquiry is not at correct stage for this action.",
          );
          return {
            ok: false,
            reason: "Wrong stage",
            attachments: [] as Attachment[],
            team: undefined as string | undefined,
          };
        }

        const responseSnap = await tx.get(responseRef);
        if (!responseSnap.exists) {
          throw new Error(`Response ${responseRef.id} not found`);
        }

        // attachments to be processed AFTER the transaction
        const raw = responseSnap.get("attachments");
        const attachments = Array.isArray(raw) ? (raw as Attachment[]) : [];

        const metaDocRef = responseRef.collection("meta").doc("data");
        const metaSnap = await tx.get(metaDocRef);
        const team = metaSnap.exists
          ? (metaSnap.get("authorTeam") as string | undefined)
          : undefined;

        // --- WRITES AFTER ALL READS ----------------------------------------------
        tx.update(responseRef, {
          isPublished: true,
          roundNumber: roundNumber + 1,
          responseNumber: 0,
          publishedAt, // serverTimestamp inside tx is fine
        });

        if (team) {
          const draftRef = db
            .collection("drafts")
            .doc("posts")
            .collection(team)
            .doc(responseRef.id);
          tx.delete(draftRef);
        } else {
          // Don't throw; just log and continue with the rest of the atomic ops
          console.warn(
            `[committeeResponseInstantPublisher] No team found for ${responseRef.id}.`,
          );
        }

        const nextStageEnds = computeStageEnds(4, { hour: 19, minute: 55 });

        tx.update(enquiryRef, {
          roundNumber: FieldValue.increment(1),
          teamsCanRespond: true,
          teamsCanComment: false,
          stageStarts: publishedAt,
          stageEnds: Timestamp.fromDate(nextStageEnds),
        });

        // Return stuff needed after commit (attachments to publish, team for logs, etc.)
        return { ok: true, attachments, team };
      });

      // 2) Post-transaction side effects (safe to retry idempotently, but kept separate)
      if (txResult?.ok && txResult.attachments?.length) {
        const updatedAttachments = await publishAttachments(
          txResult.attachments,
        );
        await responseRef.update({ attachments: updatedAttachments });
      }

      return { ok: !!txResult?.ok };
    } catch (err) {
      console.error(
        "[committeeResponseInstantPublisher] Transaction failed for " +
          `enquiry ${enquiryID}:`,
        err,
      );
      return { ok: false, error: (err as Error)?.message ?? String(err) };
    }
  },
);
