// functions/makeAdmin.ts
import { initializeApp, cert } from "firebase-admin/app";
import { getAuth } from "firebase-admin/auth";

import serviceAccount from "./serviceAccountKey.json";

import type { ServiceAccount } from "firebase-admin";
// If TS errors on JSON import, set "resolveJsonModule": true in tsconfig

const uid = "---"; // find this in Firebase Console → Authentication → Users

initializeApp({
  credential: cert(serviceAccount as ServiceAccount),
  // projectId is inside the JSON, but adding it explicitly is fine too:
  // projectId: "<your-project-id>",
});

async function main() {
  await getAuth().setCustomUserClaims(uid, { role: "admin" });
  console.log(`✅ ${uid} is now admin`);
}
main().catch(console.error);
