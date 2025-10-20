// ──────────────────────────────────────────────────────────────────────────────
// File: src/posts/storage.ts
// Purpose: Storage & filename utilities (+ bulk move)
// ──────────────────────────────────────────────────────────────────────────────
import { getStorage } from "firebase-admin/storage";

import { assert } from "../common/errors";

import type { TempAttachmentIn, FinalisedAttachment } from "../common/types";
import type { Bucket } from "@google-cloud/storage";

/** Lightweight filename sanitiser (keeps extensions). */
export function sanitiseName(name: string): string {
  return String(name)
    .replace(/[^\w.\-+]/g, "_")
    .slice(0, 200);
}

/** Ensure a unique name inside a folder by suffixing -1, -2, ... */
export async function uniqueNameFor(
  bucket: Bucket,
  folder: string, // e.g. "enquiries/abc123"
  baseName: string,
): Promise<string> {
  const safeFolder = folder.replace(/\/+$/, ""); // strip trailing slash
  const safeBase = sanitiseName(baseName);
  const dot = safeBase.lastIndexOf(".");
  const stem = dot >= 0 ? safeBase.slice(0, dot) : safeBase;
  const ext = dot >= 0 ? safeBase.slice(dot) : "";

  let i = 0;
  // Use the provided bucket
  while (
    await bucket
      .file(`${safeFolder}/${i ? `${stem}-${i}${ext}` : safeBase}`)
      .exists()
      .then((r) => r[0])
  ) {
    i += 1;
    if (i > 200) break;
  }
  return i ? `${stem}-${i}${ext}` : safeBase;
}

/**
 * Copies validated attachments to the final folder (with unique names),
 * deletes the temp files, and returns the finalised attachment list.
 */
export async function moveValidatedAttachments(options: {
  postFolder: string; // e.g. "enquiries/ID/..."
  incoming: TempAttachmentIn[];
  validated: FinalisedAttachment[]; // name + intended path (will be adjusted)
}): Promise<FinalisedAttachment[]> {
  const bucket = getStorage().bucket();
  const moved: { finalPath: string }[] = [];
  const finalised: FinalisedAttachment[] = [];

  try {
    for (const v of options.validated) {
      const temp = options.incoming.find(
        (a) => sanitiseName(a.name) === sanitiseName(v.name),
      );
      assert(!!temp, "Validated attachment not found in input.");

      const src = bucket.file(String(temp!.storagePath));
      const folder = v.path.replace(/\/[^/]+$/, ""); // strip filename
      const finalName = await uniqueNameFor(bucket, folder, v.name);
      const destPath = `${folder}/${finalName}`;
      const dest = bucket.file(destPath);

      // Copy with contentType metadata when available
      await src.copy(
        dest,
        v.contentType
          ? { metadata: { contentType: v.contentType } }
          : undefined,
      );
      await src.delete();

      moved.push({ finalPath: destPath });
      finalised.push({ ...v, name: finalName, path: destPath });
    }

    return finalised;
  } catch (e) {
    // best-effort cleanup
    await Promise.allSettled(
      moved.map(({ finalPath }) => bucket.file(finalPath).delete()),
    );
    throw e;
  }
}
