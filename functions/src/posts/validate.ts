// ──────────────────────────────────────────────────────────────────────────────
import { getStorage } from "firebase-admin/storage";
import { HttpsError } from "firebase-functions/v2/https";

import { sanitiseName } from "./storage";
import {
  ALLOWED_MIME,
  MAX_BYTES_PER_FILE,
  MAX_TOTAL_BYTES,
} from "../common/config";
import { assert, isNotFoundError, deleteAndFail } from "../common/errors";

import type {
  TempAttachmentIn,
  FinalisedAttachment,
  CreatePostData,
} from "../common/types";

export function coerceAndValidateInput(
  raw: CreatePostData,
): Required<CreatePostData> {
  const postType = raw.postType;
  if (!postType || !["enquiry", "response", "comment"].includes(postType)) {
    throw new HttpsError("invalid-argument", "Invalid or missing postType.");
  }

  const title = String(raw.title ?? "").trim();
  const postText = String(raw.postText ?? "").trim();
  const parentIds = Array.isArray(raw.parentIds)
    ? raw.parentIds.map(String)
    : [];
  const attachments = Array.isArray(raw.attachments) ? raw.attachments : [];

  if (postType !== "comment" && !postText && attachments.length === 0) {
    throw new HttpsError(
      "invalid-argument",
      "Post must contain either text or an attachment.",
    );
  }
  if (postType === "response" && parentIds.length !== 1) {
    throw new HttpsError(
      "invalid-argument",
      "Response must contain one parentId.",
    );
  }
  if (postType === "comment") {
    if (parentIds.length !== 2) {
      throw new HttpsError(
        "invalid-argument",
        "Comment must contain two parentIds.",
      );
    }
    if (attachments.length > 0) {
      throw new HttpsError(
        "invalid-argument",
        "Comments must not have attachments.",
      );
    }
  }

  return { postType, title, postText, parentIds, attachments };
}

export async function validateAttachments(options: {
  postType: CreatePostData["postType"];
  authorUid: string;
  postFolder: string; // final folder (no filename)
  incoming: TempAttachmentIn[];
}): Promise<FinalisedAttachment[]> {
  if (options.postType === "comment" || options.incoming.length === 0)
    return [];

  const bucket = getStorage().bucket();
  const tempRoot =
    options.postType === "enquiry"
      ? "enquiries_temp"
      : options.postType === "response"
        ? "responses_temp"
        : "comments_temp";
  const expectedPrefix = `${tempRoot}/${options.authorUid}/`;

  const finals: FinalisedAttachment[] = [];
  let total = 0;

  for (const a of options.incoming) {
    const name = sanitiseName(String(a?.name ?? "").trim());
    const tmpPath = String(a?.storagePath ?? "").trim();
    if (!name || !tmpPath) continue;

    if (!tmpPath.startsWith(expectedPrefix)) {
      throw new HttpsError("permission-denied", "Invalid attachment path.");
    }

    const srcFile = bucket.file(tmpPath);
    const [md] = await srcFile.getMetadata().catch((e: unknown) => {
      if (isNotFoundError(e)) {
        throw new HttpsError(
          "not-found",
          `Temp attachment not found: ${tmpPath}`,
        );
      }
      throw e;
    });

    const size = Number(md.size ?? a.size ?? 0);
    const contentType = String(
      md.contentType ?? a.contentType ?? "application/octet-stream",
    );

    if (size > MAX_BYTES_PER_FILE)
      await deleteAndFail(srcFile, "Attachment too large.");
    if (!ALLOWED_MIME.test(contentType))
      await deleteAndFail(srcFile, "Unsupported attachment type.");

    total += size;
    assert(total <= MAX_TOTAL_BYTES, "Total attachment size too large.");

    finals.push({
      name,
      path: `${options.postFolder}/${name}`,
      size,
      contentType,
    });
  }

  return finals;
}
