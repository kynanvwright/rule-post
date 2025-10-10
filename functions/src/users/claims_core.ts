import { getAuth } from "firebase-admin/auth";

export const DENY_KEYS = new Set([
  "uid",
  "email",
  "createdAt",
  "updatedAt",
  "lastLoginAt",
]);

export function pickClaimsFromDoc(
  data: Record<string, unknown>,
  onlyFields?: string[],
): Record<string, unknown> {
  const keys = onlyFields?.length ? onlyFields : Object.keys(data);
  const out: Record<string, unknown> = {};
  for (const k of keys) {
    if (DENY_KEYS.has(k)) continue;
    const v = data[k as keyof typeof data];
    if (v === undefined) continue;
    try {
      JSON.stringify(v);
    } catch {
      continue;
    }
    out[k] = v;
  }
  return out;
}

export function estimateBytes(obj: unknown): number {
  return Buffer.byteLength(JSON.stringify(obj));
}

export async function applyClaimsForUid(
  uid: string,
  fromDoc: Record<string, unknown>,
  opts: { replace?: boolean; dryRun?: boolean } = {},
): Promise<Record<string, unknown>> {
  const auth = getAuth();
  const user = await auth.getUser(uid);

  const existing = (user.customClaims ?? {}) as Record<string, unknown>;
  const finalClaims = opts.replace ? fromDoc : { ...existing, ...fromDoc };

  const size = estimateBytes(finalClaims);
  if (size > 1000) {
    throw new Error(`Claims too large for ${uid} (${size}>1000 bytes)`);
  }
  if (!opts.dryRun) await auth.setCustomUserClaims(uid, finalClaims);
  return finalClaims;
}
