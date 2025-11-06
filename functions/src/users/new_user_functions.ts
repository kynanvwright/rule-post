// import { onDocumentWritten } from "firebase-functions/v2/firestore";

// import { pickClaimsFromDoc, applyClaimsForUid } from "./claims_core";

// const COLLECTION = "user_data";
// const ALLOWED_FIELDS: string[] = []; // []=all top-level fields
// const REPLACE_EXISTING = false;

// export const markAllPostsAsUnread = onDocumentWritten(
//   `/${COLLECTION}/{uid}`,
//   async (event) => {
//     const uid = event.params.uid as string;
//     const after = event.data?.after;
//     if (!after?.exists) return; // ignore deletes by default
//     const data = after.data() as Record<string, unknown>;
//     const fromDoc = pickClaimsFromDoc(data, ALLOWED_FIELDS);
//     try {
//       const final = await applyClaimsForUid(uid, fromDoc, {
//         replace: REPLACE_EXISTING,
//       });
//       console.log(`[markAllPostsAsUnread] updated ${uid}: ${JSON.stringify(final)}`);
//     } catch (e: unknown) {
//       if (e instanceof Error) {
//         console.error(`[markAllPostsAsUnread] failed for ${uid}:`, e.message);
//       } else {
//         console.error(`[markAllPostsAsUnread] failed for ${uid}:`, String(e));
//       }
//     }
//   },
// );
