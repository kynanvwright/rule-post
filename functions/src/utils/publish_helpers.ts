// ──────────────────────────────────────────────────────────────────────────────
// File: src/schedule/helpers.ts
// Purpose: Small utilities shared by publishers
// ──────────────────────────────────────────────────────────────────────────────
import {
  FieldValue,
  Timestamp,
  getFirestore,
  type DocumentReference,
} from "firebase-admin/firestore";

import { publishAttachments } from "./make_attachments_public";

import type { Attachment } from "./make_attachments_public";

const db = getFirestore();

/** Update a doc's attachments by generating public tokens/URLs, if any exist. */
export async function tokeniseAttachmentsIfAny(
  writer: FirebaseFirestore.BulkWriter,
  ref: DocumentReference,
  attachments: unknown,
): Promise<void> {
  const list = Array.isArray(attachments) ? (attachments as Attachment[]) : [];
  if (list.length === 0) return;
  const updated = await publishAttachments(list);
  writer.update(ref, { attachments: updated });
}

/** Read authorTeam from meta subdoc ("meta/data"). Returns undefined if absent. */
export async function readAuthorTeam(
  ref: DocumentReference,
): Promise<string | undefined> {
  const metaSnap = await ref.collection("meta").doc("data").get();
  return metaSnap.exists
    ? (metaSnap.get("authorTeam") as string | undefined)
    : undefined;
}

/** Queue deletion of a team's draft for a given post id. */
export function queueDraftDelete(
  writer: FirebaseFirestore.BulkWriter,
  team: string,
  postId: string,
): void {
  const draftRef = db
    .collection("drafts")
    .doc("posts")
    .collection(team)
    .doc(postId);
  writer.delete(draftRef);
}

/** Convenience setter for stage fields on enquiries. */
export function stageUpdatePayload(nextEnds: Date) {
  return {
    stageStarts: FieldValue.serverTimestamp(),
    stageEnds: Timestamp.fromDate(nextEnds),
  } as const;
}
