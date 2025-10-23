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
  ISODate,
  BasePublishable,
  EnquiryDoc,
  ResponseDoc,
  CommentDoc,
  PublishKind,
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

/** write a compact publish event to a flat collection */
async function recordPublishEvent(payload: {
  kind: PublishKind;
  enquiryId: string;
  responseId?: string;
  commentId?: string;
  title?: string; // optional if present on the doc
  publishedAt?: ISODate; // if your docs have a scheduled time
}): Promise<void> {
  const now = Timestamp.now();
  const doc: PublishEventData = {
    ...payload,
    createdAt: now,
    publishedAt: payload.publishedAt ?? now,
    processed: false,
  };
  await db.collection("publishEvents").add(doc);
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
  enquiries: Array<Pick<PublishEventData, "enquiryId" | "title">>;
  responses: Array<Pick<PublishEventData, "enquiryId" | "responseId">>;
  comments: Array<
    Pick<PublishEventData, "enquiryId" | "responseId" | "commentId">
  >;
}): string {
  const section = <T>(
    title: string,
    items: T[],
    fmt: (x: T) => string,
  ): string =>
    items.length
      ? `<h3>${title}</h3><ul>${items
          .map((x) => `<li>${fmt(x)}</li>`)
          .join("")}</ul>`
      : "";

  return `
  <div style="font-family:system-ui,Segoe UI,Roboto,Arial">
    <h2>Newly published items</h2>
    ${section(
      "Enquiries",
      groups.enquiries,
      (e) => `Enquiry <b>${e.enquiryId}</b>${e.title ? ` — ${e.title}` : ""}`,
    )}
    ${section(
      "Responses",
      groups.responses,
      (r) => `Response <b>${r.responseId}</b> in Enquiry <b>${r.enquiryId}</b>`,
    )}
    ${section(
      "Comments",
      groups.comments,
      (c) =>
        `Comment <b>${c.commentId}</b> in Response <b>${c.responseId}</b> (Enquiry <b>${c.enquiryId}</b>)`,
    )}
    <hr />
    <p style="color:#666;font-size:12px">You receive this because you opted into updates.</p>
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

  // group by kind
  const groups = {
    enquiries: [] as Array<Pick<PublishEventData, "enquiryId" | "title">>,
    responses: [] as Array<Pick<PublishEventData, "enquiryId" | "responseId">>,
    comments: [] as Array<
      Pick<PublishEventData, "enquiryId" | "responseId" | "commentId">
    >,
  };

  for (const d of events) {
    const e = d.data();
    if (e.kind === "enquiry")
      groups.enquiries.push({ enquiryId: e.enquiryId, title: e.title });
    else if (e.kind === "response")
      groups.responses.push({
        enquiryId: e.enquiryId,
        responseId: e.responseId!,
      });
    else if (e.kind === "comment")
      groups.comments.push({
        enquiryId: e.enquiryId,
        responseId: e.responseId!,
        commentId: e.commentId!,
      });
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

    await recordPublishEvent({
      kind: "enquiry",
      enquiryId,
      title: after.title,
      publishedAt: after.publishedAt,
    });
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

    await recordPublishEvent({
      kind: "response",
      enquiryId,
      responseId,
      title: after.title,
      publishedAt: after.publishedAt,
    });
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

    await recordPublishEvent({
      kind: "comment",
      enquiryId,
      responseId,
      commentId,
      publishedAt: after.publishedAt,
    });
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
