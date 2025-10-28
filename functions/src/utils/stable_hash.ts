// ──────────────────────────────────────────────────────────────────────────────
// File: src/utils/stable_hash.ts
// Purpose: Hash attachments so they can be compared for post updates
// ──────────────────────────────────────────────────────────────────────────────
import crypto from "crypto";

export function stableHash(value: unknown): string {
  const keys =
    typeof value === "object" && value !== null
      ? Object.keys(value as Record<string, unknown>).sort()
      : [];
  const json = JSON.stringify(value, keys);
  return crypto.createHash("sha256").update(json).digest("base64");
}
