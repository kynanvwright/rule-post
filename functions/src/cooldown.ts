// functions/src/cooldown.ts
import crypto from "crypto";

import { HttpsError } from "firebase-functions/v2/https";
import Redis from "ioredis";

import type { CallableRequest } from "firebase-functions/v2/https";

// ─── Redis Client Singleton ────────────────────────────────────────────────
let _redis: Redis | null = null;
function getRedis(): Redis | null {
  if (_redis) return _redis;
  const url =
    process.env.REDIS_URL ??
    (process.env.REDIS_HOST && process.env.REDIS_PORT
      ? `redis://${process.env.REDIS_HOST}:${process.env.REDIS_PORT}`
      : undefined);
  if (!url) return null;
  _redis = new Redis(url);
  return _redis;
}

// ─── Global In-Memory Store for Dev Fallback ───────────────────────────────
declare global {
  // eslint-disable-next-line no-var
  var __cooldowns: Map<string, number> | undefined;
}

// ─── Key Builder ──────────────────────────────────────────────────────────
export function cooldownKeyFromCallable<T>(
  req: CallableRequest<T>,
  scope: string,
): string {
  const uid = req.auth?.uid;
  if (uid) return `cd:${scope}:u:${uid}`;

  // Prefer Express' get(); fall back to raw headers
  const appCheck =
    req.rawRequest.get("X-Firebase-AppCheck") ??
    (req.rawRequest.headers["x-firebase-appcheck"] as string | undefined);

  if (appCheck) {
    const h = crypto.createHash("sha256").update(appCheck).digest("hex");
    return `cd:${scope}:ac:${h}`;
  }

  const ip = req.rawRequest.ip ?? "unknown";
  return `cd:${scope}:ip:${ip}`;
}

// ─── Cooldown Enforcer ────────────────────────────────────────────────────
export async function enforceCooldown(
  key: string,
  windowSec: number,
): Promise<void> {
  const redis = getRedis();

  if (redis) {
    // Atomic SET NX EX via raw call (TS-safe)
    const ok = (await redis.call(
      "SET",
      key,
      "1",
      "NX",
      "EX",
      String(windowSec),
    )) as string | null;

    if (ok === null) {
      const ttl = await redis.ttl(key);
      const retryAfterSec = ttl > 0 ? ttl : windowSec;
      throw new HttpsError(
        "resource-exhausted",
        "This action is on cooldown. Try again later.",
        { retryAfterSec },
      );
    }
    return;
  }

  // ── In-memory fallback ──
  if (!global.__cooldowns) {
    global.__cooldowns = new Map<string, number>();
  }
  const store = global.__cooldowns;

  const now = Date.now();
  const exp = store.get(key);

  if (exp && exp > now) {
    const retryAfterSec = Math.ceil((exp - now) / 1000);
    throw new HttpsError(
      "resource-exhausted",
      "This action is on cooldown. Try again later.",
      { retryAfterSec },
    );
  }

  store.set(key, now + windowSec * 1000);
}
