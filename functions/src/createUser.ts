import { getAuth } from "firebase-admin/auth";
import { onCall, HttpsError } from "firebase-functions/v2/https";

/**
 * Callable Cloud Function to create a new Firebase Auth user.
 * Only callable by users with custom claim `teamAdmin: true`.
 */
export const createFirebaseUser = onCall(async (request) => {
  const auth = getAuth();

  // 1. Check authentication
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "You must be signed in.");
  }

  // 2. Check custom claim
  const claims = request.auth.token;
  if (claims.teamAdmin !== true) {
    throw new HttpsError(
      "permission-denied",
      "Only team admins can create new users.",
    );
  }

  // 3. Get data from request
  const { email, password } = request.data;
  if (!email || !password) {
    throw new HttpsError(
      "invalid-argument",
      "Email and password are required.",
    );
  }

  // 4. Create the user
  try {
    const userRecord = await auth.createUser({
      email,
      password,
    });
    console.log("✅ New user created:", userRecord.uid);
    return { uid: userRecord.uid, email: userRecord.email };
  } catch (err: unknown) {
    if (err instanceof Error) {
      console.error("❌ Error creating user:", err.message);
    } else {
      console.error("❌ Unknown error creating user:", err);
    }
    throw new HttpsError("internal", "Failed to create user.");
  }
});
