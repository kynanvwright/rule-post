// ──────────────────────────────────────────────────────────────────────────────
// File: src/notifications/toggle_notifications.ts
// Purpose: Allow users to choose if they receive emails
// ──────────────────────────────────────────────────────────────────────────────
import { getFirestore } from "firebase-admin/firestore";
import { onCall, HttpsError } from "firebase-functions/v2/https";

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

    // 2) Input validation
    const enabled = request.data?.enabled;
    if (typeof enabled !== "boolean") {
      throw new HttpsError("invalid-argument", "`enabled` must be a boolean.");
    }

    const db = getFirestore();
    const userRef = db.doc(`user_data/${uid}`);

    // 3) Read user doc + enforce conditions
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

    // 4) Update Firestore document
    await userRef.update({ emailNotificationsOn: enabled });

    // 5) Return final value (frontend will still refresh the ID token)
    return { success: true, emailNotificationsOn: enabled };
  },
);
