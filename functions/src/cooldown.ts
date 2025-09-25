// functions/src/cooldown.ts
import Redis from "ioredis";
import crypto from "crypto";
import { HttpsError } from "firebase-functions/v2/https";

let _redis: Redis | null = null;
function getRedis(): Redis | null {
  if (_redis) return _redis;
  const url =
    process.env.REDIS_URL ??
    (process.env.REDIS_HOST && process.env.REDIS_PORT
      ? `redis://${process.env.REDIS_HOST}:${process.env.REDIS_PORT}`
      : undefined);
  if (!url) return null; // allow in-memory fallback
  _redis = new Redis(url);
  return _redis;
}

/** Stable per-caller key: uid → AppCheck hash → IP */
export function cooldownKeyFromCallable(req: any, scope: string): string {
  const uid = req.auth?.uid as string | undefined;
  if (uid) return `cd:${scope}:u:${uid}`;

  const appCheck =
    req.rawRequest?.header?.("X-Firebase-AppCheck") ??
    req.rawRequest?.headers?.["x-firebase-appcheck"];
  if (appCheck) {
    const h = crypto.createHash("sha256").update(String(appCheck)).digest("hex");
    return `cd:${scope}:ac:${h}`;
  }

  const ip = req.rawRequest?.ip ?? "unknown";
  return `cd:${scope}:ip:${ip}`;
}

/**
 * Enforce a per-caller cooldown.
 * Allows the first call and starts a timer; blocks subsequent calls until expiry.
 * If blocked, throws HttpsError("resource-exhausted") with { retryAfterSec } details.
 */
export async function enforceCooldown(
  key: string,
  windowSec: number
): Promise<void> {
  const redis = getRedis();

  if (redis) {
    // Try to create the cooldown key if it doesn't exist (atomic)
    // OK → first call during window; null → key already exists (still cooling down)
    const ok = (await redis.call("SET", key, "1", "NX", "EX", String(windowSec))) as string | null;

    if (ok === null) {
      const ttl = await redis.ttl(key); // seconds remaining (−2 no key, −1 no expire)
      const retryAfterSec = ttl > 0 ? ttl : windowSec;
      throw new HttpsError(
        "resource-exhausted",
        "This action is on cooldown. Try again in 10 seconds.",
        { retryAfterSec }
      );
    }
    return;
  }

  // ── In-memory fallback (single instance only; fine for local dev/emulator) ──
  const now = Date.now();
  (global as any).__cooldowns ||= new Map<string, number>(); // key -> expiresAt ms
  const m: Map<string, number> = (global as any).__cooldowns;
  const exp = m.get(key);
  if (exp && exp > now) {
    const retryAfterSec = Math.ceil((exp - now) / 1000);
    throw new HttpsError(
      "resource-exhausted",
      "This action is on cooldown. Try again in 10 seconds.",
      { retryAfterSec }
    );
  }
  m.set(key, now + windowSec * 1000);
}
