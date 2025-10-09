import { getFirestore, FieldValue, Timestamp } from "firebase-admin/firestore";
import { logger } from "firebase-functions";
import { onCall, HttpsError } from "firebase-functions/v2/https";

import { Attachment, publishAttachments } from "./make_attachments_public";
import { computeStageEnds } from "./publishing_and_permissions";

const db = getFirestore();

type publishPayload = {
  enquiryID: string;
};

export const teamResponseInstantPublisher = onCall(
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
    const { enquiryID } = req.data as publishPayload;
    const enquiryDoc = await db.collection("enquiries").doc(enquiryID).get();
    if (!enquiryDoc.exists) {
      console.log("[teamResponseInstantPublisher] No matching enquiry.");
      return;
    }
    const enquiryRef = enquiryDoc.ref;
    const writer = db.bulkWriter();
    let totalResponsesPublished = 0;
    const publishedAt = FieldValue.serverTimestamp();

    // Try ordered; if that fails, fall back and sort in-memory to keep numbering stable.
    let unpublishedSnap: FirebaseFirestore.QuerySnapshot;
    try {
      unpublishedSnap = await enquiryRef
        .collection("responses")
        .where("isPublished", "==", false)
        .where("fromRC", "==", false)
        .orderBy("createdAt", "asc")
        .get();
    } catch {
      unpublishedSnap = await enquiryRef
        .collection("responses")
        .where("isPublished", "==", false)
        .where("fromRC", "==", false)
        .get();
      // optional: enforce deterministic numbering
      const sorted = [...unpublishedSnap.docs].sort(
        (a, b) =>
          (a.get("createdAt")?.toMillis?.() ?? 0) -
          (b.get("createdAt")?.toMillis?.() ?? 0),
      );
      for (let i = 0; i < sorted.length; i++) {
        writer.update(sorted[i].ref, {
          isPublished: true,
          responseNumber: i + 1,
          publishedAt,
        });
        // --- Token + URL population for this doc’s attachments
        const raw = sorted[i].get("attachments");
        const attachments = Array.isArray(raw) ? (raw as Attachment[]) : [];
        if (attachments.length > 0) {
          const updatedAttachments = await publishAttachments(attachments);
          writer.update(sorted[i].ref, { attachments: updatedAttachments });
        }
        // --- Draft delete ---
        const metaSnap = await sorted[i].ref
          .collection("meta")
          .doc("data")
          .get();
        const team = metaSnap.exists ? metaSnap.get("authorTeam") : undefined;
        if (!team) {
          logger.warn(
            `[teamResponsePublisher] No team found for ${sorted[i].id}, skipping draft delete.`,
          );
          continue;
        }
        const draftRef = db
          .collection("drafts")
          .doc("posts")
          .collection(team)
          .doc(sorted[i].id);
        writer.delete(draftRef);
        totalResponsesPublished += 1;
      }
    }

    if (!unpublishedSnap.empty) {
      const docs = unpublishedSnap.docs; // already ordered if try succeeded
      for (let i = 0; i < docs.length; i++) {
        writer.update(docs[i].ref, {
          isPublished: true,
          responseNumber: i + 1,
          publishedAt,
        });
        // --- Token + URL population for this doc’s attachments
        const raw = docs[i].get("attachments");
        const attachments = Array.isArray(raw) ? (raw as Attachment[]) : [];
        if (attachments.length > 0) {
          const updatedAttachments = await publishAttachments(attachments);
          writer.update(docs[i].ref, { attachments: updatedAttachments });
        }
        // --- Draft delete ---
        const metaSnap = await docs[i].ref.collection("meta").doc("data").get();
        const team = metaSnap.exists ? metaSnap.get("authorTeam") : undefined;
        if (!team) {
          logger.warn(
            `[teamResponseInstantPublisher] No team found for ${docs[i].id}, skipping draft delete.`,
          );
          continue;
        }
        const draftRef = db
          .collection("drafts")
          .doc("posts")
          .collection(team)
          .doc(docs[i].id);
        writer.delete(draftRef);
        totalResponsesPublished += 1;
      }
    }

    // single DRY update per enquiry
    const newStageEnds = computeStageEnds(5, { hour: 11, minute: 55 });
    writer.update(enquiryRef, {
      teamsCanRespond: false,
      teamsCanComment: true,
      stageStarts: publishedAt,
      stageEnds: Timestamp.fromDate(newStageEnds),
    });

    await writer.close();
    console.log(
      `[teamResponseInstantPublisher] Published ${totalResponsesPublished} responses.`,
    );
  },
);
