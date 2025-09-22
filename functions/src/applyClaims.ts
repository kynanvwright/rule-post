/* eslint-disable no-console */
// Usage:
// npx ts-node applyClaims.ts --serviceAccount ./serviceAccountKey.json --collection user_data [--uids uid1,uid2] [--fields role,team] [--dry-run] [--replace]

import {initializeApp, cert} from "firebase-admin/app";
import {getAuth} from "firebase-admin/auth";
import {getFirestore} from "firebase-admin/firestore";
import type {ServiceAccount} from "firebase-admin";
import * as fs from "node:fs";
import * as path from "node:path";

// -------------------------
// CLI args (no extra deps)
// -------------------------
type Cli = {
  serviceAccount: string;
  collection: string;            // defaults to "user_data" if omitted
  uids?: string[];               // optional CSV
  fields?: string[];             // optional CSV
  dryRun?: boolean;
  replace?: boolean;             // if true, set claims = selected fields only; else merge
};

function parseArgs(argv: string[]): Cli {
  const out: Cli = { serviceAccount: "", collection: "user_data" };
  const args = argv.slice(2);
  for (let i = 0; i < args.length; i++) {
    const token = args[i];
    const eqIdx = token.indexOf("=");
    const key = token.replace(/^--/, "").split("=")[0];

    // helper to get value from "=val" or next token
    const val = ((): string => {
      if (eqIdx >= 0) return token.slice(eqIdx + 1);
      const next = args[i + 1];
      if (next && !next.startsWith("--")) { i++; return next; }
      return "";
    })();

    if (key === "serviceAccount") out.serviceAccount = val;
    else if (key === "collection") out.collection = val || "user_data";
    else if (key === "uids") out.uids = (val || "").split(",").filter(Boolean);
    else if (key === "fields") out.fields = (val || "").split(",").filter(Boolean);
    else if (key === "dry-run" || key === "dryRun") out.dryRun = true;
    else if (key === "replace") out.replace = true;
  }
  if (!out.serviceAccount) {
    throw new Error(
      "Missing --serviceAccount=./serviceAccountKey.json (download from Firebase Console → Project Settings → Service accounts).",
    );
  }
  return out;
}


// -------------------------
// Validation helpers
// -------------------------

// Firebase custom claims must be JSON-serialisable; total size limit ≈ 1000 bytes.
function ensureJsonSafe(value: unknown): boolean {
  try {
    JSON.stringify(value);
    return true;
  } catch {
    return false;
  }
}

function estimateSizeBytes(obj: unknown): number {
  return Buffer.byteLength(JSON.stringify(obj));
}

// Avoid pushing obviously non-claim fields
const DENY_KEYS = new Set([
  "uid",
  "email",
  "createdAt",
  "updatedAt",
  "lastLoginAt",
]);

function pickClaimsFromDoc(
  data: Record<string, unknown>,
  onlyFields?: string[],
): Record<string, unknown> {
  const picked: Record<string, unknown> = {};
  const keys = onlyFields && onlyFields.length > 0 ? onlyFields : Object.keys(data);
  for (const k of keys) {
    if (DENY_KEYS.has(k)) continue;
    const v = data[k];
    if (v === undefined) continue;
    if (!ensureJsonSafe(v)) {
      console.warn(`⚠️  Skipping field "${k}" (not JSON-serialisable)`);
      continue;
    }
    picked[k] = v;
  }
  return picked;
}

// -------------------------
// Core
// -------------------------
async function applyClaimsForUid(
  uid: string,
  claimsFromDoc: Record<string, unknown>,
  opts: {replace: boolean; dryRun: boolean},
): Promise<void> {
  const auth = getAuth();

  // Merge with existing claims unless replace=true
  const user = await auth.getUser(uid).catch((e) => {
    console.error(`❌ getUser(${uid}) failed:`, e.errorInfo?.message ?? e.message);
    throw e;
  });

  const existing = (user.customClaims ?? {}) as Record<string, unknown>;
  const finalClaims = opts.replace ? claimsFromDoc : {...existing, ...claimsFromDoc};

  // Size check
  const size = estimateSizeBytes(finalClaims);
  if (size > 1000) {
    throw new Error(
      `Claims too large for ${uid} (${size} bytes > 1000). ` +
      `Reduce fields or use --fields to select a subset.`,
    );
  }

  if (opts.dryRun) {
    console.log(`🧪 [dry-run] Would set claims for ${uid}:`, finalClaims);
    return;
  }

  await auth.setCustomUserClaims(uid, finalClaims);
  console.log(`✅ Set claims for ${uid}:`, finalClaims);
}

async function main(): Promise<void> {
  const args = parseArgs(process.argv);

  const saPath = path.resolve(args.serviceAccount);
  const saJson = JSON.parse(fs.readFileSync(saPath, "utf8")) as ServiceAccount;

  initializeApp({credential: cert(saJson)});
  const db = getFirestore();

  // Decide which user docs to read
  let targets: Array<{uid: string; data: Record<string, unknown>}> = [];

  if (args.uids && args.uids.length > 0) {
    // Specific users
    const reads = await Promise.all(
      args.uids.map((u) => db.collection(args.collection).doc(u).get()),
    );
    for (const snap of reads) {
      if (!snap.exists) {
        console.warn(`⚠️  Skipping uid ${snap.id} (no ${args.collection}/${snap.id})`);
        continue;
      }
      targets.push({uid: snap.id, data: snap.data() as Record<string, unknown>});
    }
  } else {
    // All users in the collection
    const snap = await db.collection(args.collection).get();
    if (snap.empty) {
      console.log(`No docs found in "${args.collection}". Nothing to do.`);
      return;
    }
    targets = snap.docs.map((d) => ({uid: d.id, data: d.data() as Record<string, unknown>}));
  }

  console.log(
    `Found ${targets.length} user_data docs. ` +
      `Mode: ${args.replace ? "REPLACE" : "MERGE"}; ` +
      `${args.dryRun ? "DRY-RUN" : "APPLY"}.`,
  );

  // Apply in series (small collections) to keep logs tidy
  for (const {uid, data} of targets) {
    const claims = pickClaimsFromDoc(data, args.fields);
    if (Object.keys(claims).length === 0) {
      console.warn(`⚠️  ${uid}: no claim fields selected; skipping.`);
      continue;
    }
    await applyClaimsForUid(uid, claims, {
      replace: !!args.replace,
      dryRun: !!args.dryRun,
    });
  }

  console.log("🎉 Done.");
}

main().catch((err) => {
  console.error("Fatal error:", err);
  process.exit(1);
});
