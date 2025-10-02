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
  if (uid) {
    const k = `${scope}:u:${uid}`;
    // Optional: log once per request for traceability
    console.log(`[cooldownKey] using uid key: ${k}`);
    return k;
  }

  const appCheck =
    req.rawRequest.get("X-Firebase-AppCheck") ??
    (req.rawRequest.headers["x-firebase-appcheck"] as string | undefined);

  if (appCheck) {
    const h = crypto.createHash("sha256").update(appCheck).digest("hex");
    const k = `${scope}:ac:${h}`;
    console.log(`[cooldownKey] using appcheck key: ${k}`);
    return k;
  }

  const ip =
    // Prefer x-forwarded-for if present (Cloud Run/Load Balancer)
    (req.rawRequest.headers["x-forwarded-for"] as string | undefined)
      ?.split(",")[0]
      .trim() ||
    req.rawRequest.ip ||
    "unknown";
  const k = `${scope}:ip:${ip}`;
  console.log(`[cooldownKey] using ip key: ${k}`);
  return k;
}

// ─── Cooldown Enforcer ────────────────────────────────────────────────────
export async function enforceCooldown(
  key: string,
  windowSec: number,
): Promise<void> {
  const redis = getRedis();
  const backend = redis ? "redis" : "memory";
  console.log(
    `[cooldown] backend=${backend} key=${key} windowSec=${windowSec}`,
  );

  if (redis) {
    const ok = (await redis.call(
      "SET",
      key,
      "1",
      "NX",
      "EX",
      String(windowSec),
    )) as string | null;

    if (ok === null) {
      // Key already exists. Log TTL + value for clarity.
      const [ttl, val] = await Promise.all([redis.ttl(key), redis.get(key)]);
      console.warn(`[cooldown] BLOCK key=${key} ttl=${ttl} value=${val}`);

      const retryAfterSec = ttl > 0 ? ttl : windowSec;
      throw new HttpsError(
        "resource-exhausted",
        "This action is on cooldown. Try again shortly.",
        { retryAfterSec, key, ttl, backend: "redis" },
      );
    }

    console.log(`[cooldown] ALLOW key=${key} set=OK`);
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
    console.warn(
      `[cooldown] BLOCK (memory) key=${key} retryAfterSec=${retryAfterSec}`,
    );
    throw new HttpsError(
      "resource-exhausted",
      "This action is on cooldown. Try again shortly.",
      { retryAfterSec, key, backend: "memory" },
    );
  }

  store.set(key, now + windowSec * 1000);
  console.log(
    `[cooldown] ALLOW (memory) key=${key} nextExpiryMs=${now + windowSec * 1000}`,
  );
}

export function ns(scope: string) {
  const proj =
    process.env.GCLOUD_PROJECT || process.env.GCP_PROJECT || "unknownproj";
  const envName =
    process.env.NODE_ENV || process.env.FUNCTIONS_EMULATOR ? "dev" : "prod";
  return `cd:${proj}:${envName}:${scope}`;
}
