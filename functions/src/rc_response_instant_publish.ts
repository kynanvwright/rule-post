import { getFirestore, FieldValue, Timestamp } from "firebase-admin/firestore";
import { logger } from "firebase-functions";
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
    const callerUid = req.auth?.uid;
    if (!callerUid)
      throw new HttpsError("unauthenticated", "You must be signed in.");
    const isAdmin = req.auth?.token.role === "admin";
    const isRC = req.auth?.token.team === "RC";
    if (!isAdmin && !isRC)
      throw new HttpsError("permission-denied", "Admin/RC function only.");

    const { enquiryID, responseID } = req.data as publishPayload;
    const enquiryDoc = await db.collection("enquiries").doc(enquiryID).get();
    if (!enquiryDoc.exists) {
      logger.warn("[committeeResponseInstantPublisher] No matching enquiry.");
      return { ok: false, reason: "no-enquiry" };
    }
    const enquiryRef = enquiryDoc.ref;

    // Resolve the target response ref without reading it yet (tx will read)
    let responseRef: FirebaseFirestore.DocumentReference;
    if (responseID) {
      responseRef = enquiryRef.collection("responses").doc(responseID);
    } else {
      const committeeSnap = await enquiryRef
        .collection("responses")
        .where("fromRC", "==", true)
        .where("isPublished", "==", false)
        .get();

      if (committeeSnap.empty) {
        logger.warn(
          "[committeeResponseInstantPublisher] No unpublished RC responses.",
        );
        return { ok: false, reason: "no-unpublished-rc" };
      }
      if (committeeSnap.size !== 1) {
        logger.warn(
          "[committeeResponseInstantPublisher] Too many unpublished RC responses.",
        );
        return { ok: false, reason: "multiple-unpublished-rc" };
      }
      responseRef = committeeSnap.docs[0].ref;
    }

    const publishedAt = FieldValue.serverTimestamp();

    try {
      const txResult = await db.runTransaction(async (tx) => {
        const enquirySnap = await tx.get(enquiryRef);
        if (!enquirySnap.exists) return { ok: false, reason: "no-enquiry" };

        const e = enquirySnap.data() ?? {};
        const roundNumber =
          typeof e.roundNumber === "number" ? e.roundNumber : undefined;
        if (roundNumber === undefined)
          return { ok: false, reason: "missing-round-number" };

        const stillOpen =
          e.isOpen === true &&
          e.isPublished === true &&
          e.teamsCanRespond === false;
        if (!stillOpen) return { ok: false, reason: "wrong-stage" };

        const respSnap = await tx.get(responseRef);
        if (!respSnap.exists) return { ok: false, reason: "no-response" };

        // Guard against concurrent publishes
        if (respSnap.get("isPublished") === true) {
          return { ok: false, reason: "already-published" };
        }

        const raw = respSnap.get("attachments");
        const attachments = Array.isArray(raw) ? (raw as Attachment[]) : [];

        // Optional: verify fromRC is true to enforce invariant
        if (respSnap.get("fromRC") !== true)
          return { ok: false, reason: "not-rc-response" };

        const metaSnap = await tx.get(
          responseRef.collection("meta").doc("data"),
        );
        const team = metaSnap.exists
          ? (metaSnap.get("authorTeam") as string | undefined)
          : undefined;

        tx.update(responseRef, {
          isPublished: true,
          roundNumber: roundNumber + 1,
          responseNumber: 0,
          publishedAt,
        });

        if (team) {
          const draftRef = db
            .collection("drafts")
            .doc("posts")
            .collection(team)
            .doc(responseRef.id);
          tx.delete(draftRef);
        } else {
          logger.warn(
            `[committeeResponseInstantPublisher] No team for ${responseRef.id}.`,
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

        return { ok: true, attachments };
      });

      if (txResult?.ok && txResult.attachments?.length) {
        const updatedAttachments = await publishAttachments(
          txResult.attachments,
        );
        await responseRef.update({ attachments: updatedAttachments });
      }

      return {
        ok: !!txResult?.ok,
        reason: txResult?.ok ? undefined : txResult?.reason,
      };
    } catch (err) {
      logger.error(
        "[committeeResponseInstantPublisher] Transaction failed for enquiry " +
          enquiryID +
          ":",
        err,
      );
      return {
        ok: false,
        reason: "tx-failed",
        error: (err as Error)?.message ?? String(err),
      };
    }
  },
);
