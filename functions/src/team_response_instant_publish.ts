import { getFirestore, FieldValue, Timestamp } from "firebase-admin/firestore";
import { logger } from "firebase-functions";
import { onCall, HttpsError } from "firebase-functions/v2/https";

import { Attachment, publishAttachments } from "./make_attachments_public";
import { computeStageEnds } from "./publishing_and_permissions";

const db = getFirestore();

type publishPayload = { enquiryID: string };

export const teamResponseInstantPublisher = onCall(
  { cors: true, enforceAppCheck: true },
  async (req) => {
    // 1) AuthZ
    const callerUid = req.auth?.uid;
    if (!callerUid)
      throw new HttpsError("unauthenticated", "You must be signed in.");
    const isAdmin = req.auth?.token.role === "admin";
    const isRC = req.auth?.token.team === "RC";
    if (!isAdmin && !isRC) {
      throw new HttpsError("permission-denied", "Admin/RC function only.");
    }

    // 2) Fetch enquiry
    const { enquiryID } = req.data as publishPayload;
    const enquiryDoc = await db.collection("enquiries").doc(enquiryID).get();
    if (!enquiryDoc.exists) {
      logger.warn("[teamResponseInstantPublisher] No matching enquiry.");
      return { ok: false, num_published: 0 };
    }

    const enquiryRef = enquiryDoc.ref;
    const writer = db.bulkWriter();
    const publishedAt = FieldValue.serverTimestamp();

    // 3) Get unpublished team responses, ordered if possible
    let docs: FirebaseFirestore.QueryDocumentSnapshot[] = [];
    try {
      const snap = await enquiryRef
        .collection("responses")
        .where("isPublished", "==", false)
        .where("fromRC", "==", false)
        .orderBy("createdAt", "asc")
        .get();
      docs = snap.docs;
    } catch {
      const snap = await enquiryRef
        .collection("responses")
        .where("isPublished", "==", false)
        .where("fromRC", "==", false)
        .get();
      docs = [...snap.docs].sort(
        (a, b) =>
          (a.get("createdAt")?.toMillis?.() ?? 0) -
          (b.get("createdAt")?.toMillis?.() ?? 0),
      );
    }

    // 4) Single processing loop
    let totalResponsesPublished = 0;
    for (let i = 0; i < docs.length; i++) {
      const doc = docs[i];

      writer.update(doc.ref, {
        isPublished: true,
        responseNumber: i + 1,
        publishedAt,
      });

      // Attachments (populate token/URL once)
      const raw = doc.get("attachments");
      const attachments = Array.isArray(raw) ? (raw as Attachment[]) : [];
      if (attachments.length > 0) {
        const updatedAttachments = await publishAttachments(attachments);
        writer.update(doc.ref, { attachments: updatedAttachments });
      }

      // Delete draft (idempotent if already gone)
      const metaSnap = await doc.ref.collection("meta").doc("data").get();
      const team = metaSnap.exists ? metaSnap.get("authorTeam") : undefined;
      if (!team) {
        logger.warn(
          `[teamResponseInstantPublisher] No team for ${doc.id}, skipping draft delete.`,
        );
        continue; // don't count if we couldn't attribute a team/draft
      }
      const draftRef = db
        .collection("drafts")
        .doc("posts")
        .collection(team)
        .doc(doc.id);
      writer.delete(draftRef);

      totalResponsesPublished += 1;
    }

    // 5) Advance stage
    const newStageEnds = computeStageEnds(5, { hour: 11, minute: 55 });
    writer.update(enquiryRef, {
      teamsCanRespond: false,
      teamsCanComment: true,
      stageStarts: publishedAt, // when publishing started
      stageEnds: Timestamp.fromDate(newStageEnds),
    });

    await writer.close();
    logger.info(
      `[teamResponseInstantPublisher] Published ${totalResponsesPublished} responses.`,
    );
    return { ok: true, num_published: totalResponsesPublished };
  },
);
