// ──────────────────────────────────────────────────────────────────────────────
// File: src/notifications/send_email_on_publish.ts
// Purpose: Record new posts and publish daily digest to users
// ──────────────────────────────────────────────────────────────────────────────
import { getFirestore, FieldValue, Timestamp } from "firebase-admin/firestore";
// import { defineSecret } from "firebase-functions/params";
import { logger } from "firebase-functions/v2";
import { onDocumentUpdated } from "firebase-functions/v2/firestore";
import { onSchedule } from "firebase-functions/v2/scheduler";
import { Resend } from "resend";

import {
  // ISODate,
  BasePublishable,
  EnquiryDoc,
  ResponseDoc,
  CommentDoc,
  // PublishKind,
  PublishEventData,
  EnquiryParams,
  ResponseParams,
  CommentParams,
  UserData,
} from "../common/types";

const db = getFirestore();
// const RESEND_API_KEY = defineSecret("RESEND_API_KEY");

/* ─────────────────────────── helpers ─────────────────────────── */

function becamePublished(
  before: Pick<BasePublishable, "isPublished"> | undefined,
  after: Pick<BasePublishable, "isPublished"> | undefined,
): boolean {
  if (!before || !after) return false;
  return Boolean(after.isPublished) && before.isPublished !== after.isPublished;
}

/** all recipients who opted in */
async function getRecipients(): Promise<string[]> {
  const snap = await db
    .collection("user_data")
    .where("emailNotificationsOn", "==", true)
    .get();

  return snap.docs
    .map((d) => (d.data() as UserData).email)
    .filter((e): e is string => Boolean(e));
}

/** simple digest email HTML */
function renderDigestHTML(groups: {
  enquiries: Array<
    Pick<PublishEventData, "enquiryId" | "enquiryTitle" | "enquiryNumber">
  >;
  responses: Array<
    Pick<
      PublishEventData,
      | "enquiryId"
      | "enquiryTitle"
      | "enquiryNumber"
      | "responseId"
      | "roundNumber"
      | "responseNumber"
    >
  >;
  comments: Array<
    Pick<
      PublishEventData,
      | "enquiryId"
      | "enquiryNumber"
      | "enquiryTitle"
      | "responseId"
      | "roundNumber"
      | "responseNumber"
    >
  >;
}): string {
  const section = <T>(
    title: string,
    items: T[],
    fmt: (x: T) => string,
  ): string =>
    items.length
      ? `<h3>${title}</h3><ul>${items.map((x) => `<li>${fmt(x)}</li>`).join("")}</ul>`
      : "";

  const plural = (n: number, one: string, many: string) =>
    n === 1 ? one : many;

  // --- Group comments by (enquiryId, responseId) ---
  type CommentSummary = {
    enquiryId: string;
    enquiryNumber: string;
    enquiryTitle: string;
    responseId: string;
    roundNumber: string;
    responseNumber: string;
    count: number;
  };

  const groupedComments = Array.from(
    groups.comments
      .reduce((m, c) => {
        const key = `${c.enquiryId}::${c.responseId}`;
        const found = m.get(key);
        if (found) {
          found.count += 1;
        } else {
          m.set(key, {
            enquiryId: c.enquiryId,
            enquiryNumber: c.enquiryNumber,
            enquiryTitle: c.enquiryTitle,
            responseId: c.responseId,
            roundNumber: c.roundNumber,
            responseNumber: c.responseNumber,
            count: 1,
          } as CommentSummary);
        }
        return m;
      }, new Map<string, CommentSummary>())
      .values(),
  );

  // Precompute the comments list items as strings
  const commentItems = groupedComments.map(
    (g) =>
      `<a href="https://rulepost.com/#/enquiries/${g.enquiryId}/responses/${g.responseId}"
        style="color:#007bff;text-decoration:none;">
        ${g.count} ${plural(g.count, "comment", "comments")} on Response ${g.roundNumber}.${g.responseNumber}
     </a>
     of Rule Enquiry #${g.enquiryNumber} — ${g.enquiryTitle}`,
  );

  return `
  <div style="font-family:system-ui,Segoe UI,Roboto,Arial">
    <h2>Newly published posts on RulePost:</h2>
    ${section(
      "Enquiries",
      groups.enquiries,
      (e) =>
        `Rule Enquiry #${e.enquiryNumber} — 
         <a href="https://rulepost.com/#/enquiries/${e.enquiryId}"
            style="color:#007bff;text-decoration:none;">
            ${e.enquiryTitle}
         </a>`,
    )}
    ${section(
      "Responses",
      groups.responses,
      (r) =>
        `<a href="https://rulepost.com/#/enquiries/${r.enquiryId}/responses/${r.responseId}"
           style="color:#007bff;text-decoration:none;">
           Response ${r.roundNumber}.${r.responseNumber}
         </a>
         in Rule Enquiry #${r.enquiryNumber} — ${r.enquiryTitle}`,
    )}
    ${section("Comments", commentItems, (html) => html)}
    <hr />
    <p style="color:#666;font-size:12px">You receive this because you opted into updates
      <a href="https://rulepost.com/#/user-details"
        style="color:#007bff;text-decoration:underline;margin-left:4px;">
        unsubscribe
      </a>
    </p>
  </div>`;
}

/** send one digest to all recipients, then mark events processed */
async function sendDigestFor(
  events: FirebaseFirestore.QueryDocumentSnapshot<PublishEventData>[],
): Promise<void> {
  if (events.length === 0) return;

  const to = await getRecipients();
  if (!to.length) {
    logger.info("No recipients; marking events processed without sending.");
    const batch = db.batch();
    events.forEach((d) =>
      batch.update(d.ref, {
        processed: true,
        processedAt: FieldValue.serverTimestamp(),
      }),
    );
    await batch.commit();
    return;
  }

  type Groups = {
    enquiries: PublishEventData[];
    responses: PublishEventData[];
    comments: PublishEventData[];
  };

  const groups: Groups = { enquiries: [], responses: [], comments: [] };

  for (const d of events) {
    const e = d.data();
    if (e.kind === "enquiry") groups.enquiries.push(e);
    else if (e.kind === "response") groups.responses.push(e);
    else if (e.kind === "comment") groups.comments.push(e);
  }

  const html = renderDigestHTML(groups);
  const subject = "Rule Post — items published";

  const resend = new Resend(process.env.RESEND_API_KEY as string);
  await resend.emails.send({
    from: "Rule Post <send@rulepost.com>", // must be verified in Resend
    to,
    subject,
    html,
  });

  const batch = db.batch();
  events.forEach((d) =>
    batch.update(d.ref, {
      processed: true,
      processedAt: FieldValue.serverTimestamp(),
    }),
  );
  await batch.commit();
}

/* ───────────────────── triggers (write events) ───────────────────── */

// enquiries/{enquiryId}
export const onEnquiryIsPublishedUpdated = onDocumentUpdated(
  { document: "enquiries/{enquiryId}", secrets: ["RESEND_API_KEY"] },
  async (event): Promise<void> => {
    const before = event.data?.before?.data() as EnquiryDoc | undefined;
    const after = event.data?.after?.data() as EnquiryDoc | undefined;
    if (!becamePublished(before, after) || !after) return;

    const { enquiryId } = event.params as EnquiryParams;

    const now = Timestamp.now();
    const doc: PublishEventData = {
      kind: "enquiry",
      enquiryId,
      enquiryTitle: after.title,
      enquiryNumber: after.enquiryNumber,
      publishedAt: after.publishedAt ?? now,
      createdAt: now,
      processed: false,
    };
    await db.collection("publishEvents").add(doc);
  },
);

// enquiries/{enquiryId}/responses/{responseId}
export const onResponseIsPublishedUpdated = onDocumentUpdated(
  {
    document: "enquiries/{enquiryId}/responses/{responseId}",
    secrets: ["RESEND_API_KEY"],
  },
  async (event): Promise<void> => {
    const before = event.data?.before?.data() as ResponseDoc | undefined;
    const after = event.data?.after?.data() as ResponseDoc | undefined;
    if (!becamePublished(before, after) || !after) return;

    const { enquiryId, responseId } = event.params as ResponseParams;

    // 🔍 Fetch the parent enquiry document
    const enquirySnap = await db.collection("enquiries").doc(enquiryId).get();
    const enquiryData = enquirySnap.data() as EnquiryDoc | undefined;
    const enquiryTitle = enquiryData?.title ?? "(Untitled enquiry)";
    const enquiryNumber = enquiryData?.enquiryNumber ?? "(Unnumbered enquiry)";

    const now = Timestamp.now();
    const doc: PublishEventData = {
      kind: "response",
      enquiryId,
      responseId,
      enquiryTitle: enquiryTitle,
      enquiryNumber: enquiryNumber,
      roundNumber: after.roundNumber,
      responseNumber: after.responseNumber,
      publishedAt: after.publishedAt ?? now,
      createdAt: now,
      processed: false,
    };
    await db.collection("publishEvents").add(doc);
  },
);

// enquiries/{enquiryId}/responses/{responseId}/comments/{commentId}
export const onCommentIsPublishedUpdated = onDocumentUpdated(
  {
    document:
      "enquiries/{enquiryId}/responses/{responseId}/comments/{commentId}",
    secrets: ["RESEND_API_KEY"],
  },
  async (event): Promise<void> => {
    const before = event.data?.before?.data() as CommentDoc | undefined;
    const after = event.data?.after?.data() as CommentDoc | undefined;
    if (!becamePublished(before, after) || !after) return;

    const { enquiryId, responseId, commentId } = event.params as CommentParams;

    // 🔍 Fetch the parent enquiry document
    const enquirySnap = await db.collection("enquiries").doc(enquiryId).get();
    const enquiryData = enquirySnap.data() as EnquiryDoc | undefined;
    const enquiryTitle = enquiryData?.title ?? "(Untitled enquiry)";
    const enquiryNumber = enquiryData?.enquiryNumber ?? "(Unnumbered enquiry)";
    const responseSnap = await db
      .collection("enquiries")
      .doc(enquiryId)
      .collection("responses")
      .doc(responseId)
      .get();
    const responseData = responseSnap.data() as ResponseDoc | undefined;
    const responseRound = responseData?.roundNumber ?? "x";
    const responseNumber = responseData?.responseNumber ?? "x";

    const now = Timestamp.now();
    const doc: PublishEventData = {
      kind: "comment",
      enquiryId,
      responseId,
      commentId,
      enquiryTitle: enquiryTitle,
      enquiryNumber: enquiryNumber,
      roundNumber: responseRound,
      responseNumber: responseNumber,
      publishedAt: after.publishedAt ?? now,
      createdAt: now,
      processed: false,
    };
    await db.collection("publishEvents").add(doc);
  },
);

/* ───────────────────── scheduler (send digest) ───────────────────── */

export const sendPublishDigest = onSchedule(
  {
    // 00:05, 12:05, and 20:05 every day
    schedule: "5 0,12,20 * * *",
    timeZone: "Europe/Rome",
    secrets: ["RESEND_API_KEY"],
    region: "europe-west6",
  },
  async (): Promise<void> => {
    const now = Timestamp.now();
    const snap = await db
      .collection("publishEvents")
      .where("processed", "==", false)
      .where("publishedAt", "<=", now)
      .orderBy("publishedAt", "asc")
      .limit(500)
      .get();

    // type-annotate here so .data() is strongly typed above
    const docs =
      snap.docs as FirebaseFirestore.QueryDocumentSnapshot<PublishEventData>[];
    await sendDigestFor(docs);
    logger.info("Digest processed", { count: snap.size });
  },
);
