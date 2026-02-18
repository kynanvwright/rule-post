import { randomUUID } from "crypto";

import { getStorage } from "firebase-admin/storage";

// Types are optional but nice to have
export type Attachment = {
  name?: string;
  path?: string; // e.g. "enquiries/<eid>/responses/<rid>/<file>"
  url?: string; // will be overwritten with tokened URL on publish
  token?: string; // optional, for debugging/visibility
  size?: number;
  contentType?: string;
};

const bucket = getStorage().bucket();

const buildPublicUrl = (path: string, token: string) =>
  `https://firebasestorage.googleapis.com/v0/b/${bucket.name}/o/${encodeURIComponent(path)}?alt=media&token=${token}`;

async function getOrCreateDownloadToken(
  file: import("@google-cloud/storage").File,
): Promise<string> {
  const [meta] = await file.getMetadata();
  const existing = String(
    meta.metadata?.firebaseStorageDownloadTokens ?? "",
  ).trim();

  if (existing) {
    // Firebase may store multiple tokens as comma-separated
    return existing.split(",")[0].trim();
  }
  const token = randomUUID();
  // Set download token + cache headers for published files
  await file.setMetadata({
    metadata: { firebaseStorageDownloadTokens: token },
    cacheControl: "public, max-age=3600", // Cache for 1 hour
  });
  return token;
}

/**
 * For one document: ensure every attachment with a `path` has a tokened, public URL.
 * Returns a new array you can write back to Firestore.
 */
export async function publishAttachments(
  attachments: Attachment[],
): Promise<Attachment[]> {
  if (!attachments?.length) return attachments ?? [];

  // Process in parallel, but skip entries without a path.
  const updated = await Promise.all(
    attachments.map(async (att) => {
      const path = att.path?.trim();
      if (!path) return att; // nothing to do

      const file = bucket.file(path);
      const token = await getOrCreateDownloadToken(file);
      const publicUrl = buildPublicUrl(path, token);

      return { ...att, url: publicUrl, token };
    }),
  );

  return updated;
}
