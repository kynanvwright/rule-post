import { onDocumentWritten } from "firebase-functions/v2/firestore";

import { pickClaimsFromDoc, applyClaimsForUid } from "./claims_core";

const COLLECTION = "user_data";
const ALLOWED_FIELDS: string[] = []; // []=all top-level fields
const REPLACE_EXISTING = false;

export const syncCustomClaims = onDocumentWritten(
  `/${COLLECTION}/{uid}`,
  async (event) => {
    const uid = event.params.uid as string;
    const after = event.data?.after;
    if (!after?.exists) return; // ignore deletes by default
    const data = after.data() as Record<string, unknown>;
    const fromDoc = pickClaimsFromDoc(data, ALLOWED_FIELDS);
    try {
      const final = await applyClaimsForUid(uid, fromDoc, {
        replace: REPLACE_EXISTING,
      });
      console.log(`[claims_sync] updated ${uid}: ${JSON.stringify(final)}`);
    } catch (e: unknown) {
      if (e instanceof Error) {
        console.error(`[claims_sync] failed for ${uid}:`, e.message);
      } else {
        console.error(`[claims_sync] failed for ${uid}:`, String(e));
      }
    }
  },
);
