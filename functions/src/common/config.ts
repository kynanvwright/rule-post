// ────────────────────────────────────────────────────────────────────────────
// File: src/common/config.ts
// Purpose: Central config constants
// ────────────────────────────────────────────────────────────────────────────
export const REGION = "europe-west8";
export const SCHED_REGION_ROME = "europe-west6" as const;
export const ROME_TZ = "Europe/Rome";
export const MEMORY = "256MiB" as const;
export const TIMEOUT_SECONDS = 30 as const;

export const ALLOWED_TYPES = [
  "application/pdf",
  "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
  "application/msword",
] as const;
export const ALLOWED_MIME = new RegExp(`^(${ALLOWED_TYPES.join("|")})$`, "i");

export const MAX_BYTES_PER_FILE = 25 * 1024 * 1024; // 25 MB
export const MAX_TOTAL_BYTES = 100 * 1024 * 1024; // 100 MB (all attachments)
