/* eslint-disable no-console */
// Usage:
// npx ts-node applyClaims.ts --serviceAccount ./serviceAccountKey.json --collection user_data [--uids uid1,uid2] [--fields role,team] [--dry-run] [--replace]
import * as fs from "node:fs";
import * as path from "node:path";

import { initializeApp, cert } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";

import { pickClaimsFromDoc, applyClaimsForUid } from "./claims_core";

import type { ServiceAccount } from "firebase-admin";

type Cli = {
  serviceAccount: string;
  collection: string;
  uids?: string[];
  fields?: string[];
  dryRun?: boolean;
  replace?: boolean;
};
function parseArgs(argv: string[]): Cli {
  const out: Cli = { serviceAccount: "", collection: "user_data" };
  const args = argv.slice(2);
  for (let i = 0; i < args.length; i++) {
    const t = args[i];
    const eq = t.indexOf("=");
    const key = t.replace(/^--/, "").split("=")[0];
    const val = ((): string => {
      if (eq >= 0) return t.slice(eq + 1);
      const n = args[i + 1];
      if (n && !n.startsWith("--")) {
        i++;
        return n;
      }
      return "";
    })();
    if (key === "serviceAccount") out.serviceAccount = val;
    else if (key === "collection") out.collection = val || "user_data";
    else if (key === "uids") out.uids = (val || "").split(",").filter(Boolean);
    else if (key === "fields")
      out.fields = (val || "").split(",").filter(Boolean);
    else if (key === "dry-run" || key === "dryRun") out.dryRun = true;
    else if (key === "replace") out.replace = true;
  }
  if (!out.serviceAccount)
    throw new Error("Missing --serviceAccount=./serviceAccountKey.json");
  return out;
}

async function main(): Promise<void> {
  const args = parseArgs(process.argv);
  const saPath = path.resolve(args.serviceAccount);
  const saJson = JSON.parse(fs.readFileSync(saPath, "utf8")) as ServiceAccount;
  initializeApp({ credential: cert(saJson) });
  const db = getFirestore();

  let targets: Array<{ uid: string; data: Record<string, unknown> }> = [];

  if (args.uids?.length) {
    const reads = await Promise.all(
      args.uids.map((u) => db.collection(args.collection).doc(u).get()),
    );
    for (const snap of reads) {
      if (!snap.exists) {
        console.warn(`⚠️ no ${args.collection}/${snap.id}`);
        continue;
      }
      targets.push({
        uid: snap.id,
        data: snap.data() as Record<string, unknown>,
      });
    }
  } else {
    const snap = await db.collection(args.collection).get();
    if (snap.empty) {
      console.log(`No docs in "${args.collection}".`);
      return;
    }
    targets = snap.docs.map((d) => ({
      uid: d.id,
      data: d.data() as Record<string, unknown>,
    }));
  }

  console.log(
    `Targets: ${targets.length}. Mode: ${args.replace ? "REPLACE" : "MERGE"}; ${args.dryRun ? "DRY-RUN" : "APPLY"}.`,
  );

  for (const { uid, data } of targets) {
    const fromDoc = pickClaimsFromDoc(data, args.fields);
    if (Object.keys(fromDoc).length === 0) {
      console.warn(`⚠️ ${uid}: no claim fields; skipping.`);
      continue;
    }
    const final = await applyClaimsForUid(uid, fromDoc, {
      replace: !!args.replace,
      dryRun: !!args.dryRun,
    });
    console.log(`✅ ${uid}: ${JSON.stringify(final)}`);
  }
}

main().catch((e) => {
  console.error("Fatal error:", e);
  process.exit(1);
});
