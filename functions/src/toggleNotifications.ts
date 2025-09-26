// functions/src/index.ts (or wherever you export functions v2)
import { getFirestore } from "firebase-admin/firestore";
import { onCall, HttpsError } from "firebase-functions/v2/https";
// import { getAuth } from "firebase-admin/auth";

import { enforceCooldown, cooldownKeyFromCallable } from "./cooldown";

/**
 * Callable v2 function: setEmailNotificationsOn
 * - Only the signed-in user can update their own setting
 * - Conditions enforced here:
 *     1) user doc must exist
 *     2) user must be active (isActive === true)
 * - Updates both Firestore and the user's custom claims
 */
export const setEmailNotificationsOn = onCall(
  { cors: true, enforceAppCheck: true }, // adjust region if needed
  async (request) => {
    // 1) Auth check
    const uid = request.auth?.uid;
    if (!uid) {
      throw new HttpsError("unauthenticated", "You must be signed in.");
    }
    // 2) Enforce cooldown (e.g., 60s per caller for createPost)
    const key = cooldownKeyFromCallable(request, "createPost");
    await enforceCooldown(key, 10);

    // 3) Input validation
    const enabled = request.data?.enabled;
    if (typeof enabled !== "boolean") {
      throw new HttpsError("invalid-argument", "`enabled` must be a boolean.");
    }

    const db = getFirestore();
    const userRef = db.doc(`user_data/${uid}`);

    // 4) Read user doc + enforce conditions
    const snap = await userRef.get();
    if (!snap.exists) {
      throw new HttpsError("failed-precondition", "User profile not found.");
    }

    const emailNotificationsOn = snap.get("emailNotificationsOn") as
      | boolean
      | undefined;
    if (
      typeof emailNotificationsOn === "boolean" &&
      emailNotificationsOn !== request.auth?.token.emailNotificationsOn
    ) {
      throw new HttpsError(
        "invalid-argument",
        "Boolean mismatch between custom claim and firestore.",
      );
    }

    // 5) Update Firestore document
    await userRef.update({ emailNotificationsOn: enabled });

    // // 6) Mirror into custom claims so the client can read it after ID token refresh
    // // NOTE: commented out because this should be automatically triggered by another cloud function
    // const auth = getAuth();
    // const userRecord = await auth.getUser(uid);
    // const currentClaims = userRecord.customClaims ?? {};
    // await auth.setCustomUserClaims(uid, {
    //   ...currentClaims,
    //   emailNotificationsOn: enabled,
    // });

    // 6) Return final value (frontend will still refresh the ID token)
    return { success: true, emailNotificationsOn: enabled };
  },
);
