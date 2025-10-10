// ────────────────────────────────────────────────────────────────────────────
// File: src/common/errors.ts
// Purpose: Error helpers & assertions
// ────────────────────────────────────────────────────────────────────────────
import { HttpsError } from "firebase-functions/v2/https";

import type { File } from "@google-cloud/storage";

export function assert(cond: unknown, msg: string): asserts cond {
  if (!cond) throw new HttpsError("failed-precondition", msg);
}

/** GCS 404 detector without using any. */
export function isNotFoundError(e: unknown): boolean {
  return (
    typeof e === "object" &&
    e !== null &&
    "code" in e &&
    (e as { code?: number }).code === 404
  );
}

/** Delete a file then always fail with a clean error. */
export async function deleteAndFail(
  file: File,
  message: string,
): Promise<never> {
  try {
    await file.delete();
  } catch {
    /* ignore */
  }
  throw new HttpsError("failed-precondition", message);
}
