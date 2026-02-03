// ──────────────────────────────────────────────────────────────────────────────
// File: src/notifications/send_email_on_publish.ts
// Purpose: Record new posts and publish daily digest to users
// ──────────────────────────────────────────────────────────────────────────────
import { getFirestore, FieldValue, Timestamp } from "firebase-admin/firestore";
import { logger } from "firebase-functions/v2";
import { onDocumentUpdated } from "firebase-functions/v2/firestore";
import { onSchedule } from "firebase-functions/v2/scheduler";
import { Resend } from "resend";

import {
  BasePublishable,
  EnquiryDoc,
  ResponseDoc,
  CommentDoc,
  PublishEventData,
  EnquiryParams,
  ResponseParams,
  CommentParams,
  UserData,
} from "../common/types";

const db = getFirestore();

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

  // tiny helper to prevent broken markup / injection from titles
  const esc = (s: string | undefined) =>
    (s ?? "")
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;")
      .replace(/"/g, "&quot;")
      .replace(/'/g, "&#39;");

  // shared inline styles for links and small/muted text
  const linkStyle = "color:#007bff;text-decoration:underline;";
  const muted = "color:#666;";

  // table row builder (avoids <ul> quirks in Outlook)
  const sectionTable = <T>(
    title: string,
    items: T[],
    fmt: (x: T) => string,
  ): string =>
    items.length
      ? `
        <tr>
          <td style="padding:16px 0 8px 0;font-weight:600;font-size:16px">${title}</td>
        </tr>
        ${items
          .map(
            (x) => `
            <tr>
              <td style="padding:8px 0;font-size:14px;line-height:1.4">
                ${fmt(x)}
              </td>
            </tr>`,
          )
          .join("")}
      `
      : "";

  // Precompute the comments list items as strings (kept from your logic)
  const commentItems = groupedComments.map(
    (g) =>
      `${g.count} ${plural(g.count, "comment", "comments")} on 
      <a href="https://rulepost.com/#/enquiries/${g.enquiryId}/responses/${g.responseId}" style="${linkStyle}">
      Response ${g.roundNumber}.${g.responseNumber}</a> of Rule Enquiry #${g.enquiryNumber} — ${esc(g.enquiryTitle)}`,
  );

  return `
  <!-- Preheader (hidden) -->
  <div style="display:none;max-height:0;overflow:hidden;opacity:0;font-size:1px;line-height:1px;">
    New Rule Post publications: enquiries, responses, and comments.
  </div>

  <table role="presentation" cellpadding="0" cellspacing="0" border="0" width="100%" style="background:#f6f7f9;padding:24px 0;">
    <tr>
      <td align="center">
        <table role="presentation" cellpadding="0" cellspacing="0" border="0" width="600" style="width:100%;max-width:600px;background:#ffffff;border-radius:6px;overflow:hidden;">
          <tr>
            <td style="padding:20px 24px;font-family:system-ui,Segoe UI,Roboto,Arial,sans-serif;">
              <h2 style="margin:0 0 12px 0;font-size:20px;line-height:1.3;font-weight:700;">
                Newly published on Rule Post:
              </h2>

              <table role="presentation" cellpadding="0" cellspacing="0" border="0" width="100%">
                ${sectionTable(
                  "Enquiries",
                  groups.enquiries,
                  (e) =>
                    `Rule Enquiry #${e.enquiryNumber} — 
                    <a href="https://rulepost.com/#/enquiries/${e.enquiryId}" style="${linkStyle}">
                      ${esc(e.enquiryTitle)}
                    </a>`,
                )}

                ${sectionTable(
                  "Responses",
                  groups.responses,
                  (r) =>
                    `<a href="https://rulepost.com/#/enquiries/${r.enquiryId}/responses/${r.responseId}" style="${linkStyle}" aria-label="Response ${r.roundNumber}.${r.responseNumber}">
                      Response ${r.roundNumber}.${r.responseNumber}</a> to Rule Enquiry #${r.enquiryNumber} — ${esc(r.enquiryTitle)}`,
                )}

                ${sectionTable("Comments", commentItems, (html) => html)}
              </table>

              <hr style="border:none;border-top:1px solid #e6e7eb;margin:16px 0;" />

              <p style="${muted};font-size:12px;margin:0;">
                You receive this because you opted into updates.
                <a href="https://rulepost.com/#/user-details" style="${linkStyle};margin-left:4px;">
                  Manage email settings
                </a>
              </p>
            </td>
          </tr>
        </table>

        <!-- optional footer spacing for mobile tap comfort -->
        <div style="height:24px;line-height:24px;">&#8202;</div>
      </td>
    </tr>
  </table>
  `;
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
  const subject = "New publications on Rule Post";

  const resend = new Resend(process.env.RESEND_API_KEY as string);
  await resend.emails.send({
    from: "Rule Post <send@rulepost.com>", // must be verified in Resend
    to: "Rule Post <send@rulepost.com>", // should be an internal address
    bcc: to, // mailing list moved to bcc for privacy
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
  { document: "enquiries/{enquiryId}" },
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
  { document: "enquiries/{enquiryId}/responses/{responseId}" },
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
