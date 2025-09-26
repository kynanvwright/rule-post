import { getAuth } from "firebase-admin/auth";
import { getFirestore, FieldValue } from "firebase-admin/firestore";
import { onCall, HttpsError } from "firebase-functions/v2/https";

const auth = getAuth(); // ✅ this returns an Auth instance (not callable)
const db = getFirestore(); // ✅ Firestore instance

type CreateUserPayload = { email: string; password: string };

export const createUserWithProfile = onCall(
  { cors: true, enforceAppCheck: true },
  async (req) => {
    const { email, password } = req.data as CreateUserPayload;

    if (!email || !password) {
      throw new HttpsError("invalid-argument", "Missing email or password.");
    }

    // 1) Create the Auth user
    let userRecord;
    try {
      userRecord = await auth.createUser({ email, password });
      console.log("✅ New user created:", userRecord.uid);
    } catch (e: unknown) {
      // Normalise error shape (covers firebase-admin's errorInfo.code and plain code)
      const err = e as { code?: string; errorInfo?: { code?: string } } | null;
      const code = err?.errorInfo?.code ?? err?.code;

      const map: Record<string, HttpsError> = {
        "auth/email-already-exists": new HttpsError(
          "already-exists",
          "Email already in use.",
        ),
        "auth/invalid-email": new HttpsError(
          "invalid-argument",
          "Invalid email format.",
        ),
        "auth/invalid-password": new HttpsError(
          "invalid-argument",
          "Invalid password (does not meet policy).",
        ),
      };

      if (code && map[code]) {
        throw map[code];
      }

      console.error("❌ Auth error:", e);
      throw new HttpsError("internal", "Failed to create auth user.");
    }

    // 2) Create Firestore profile doc
    try {
      await db
        .collection("user_data")
        .doc(userRecord.uid)
        .set({
          email: userRecord.email ?? email,
          role: "user",
          team: req.auth?.token.team,
          emailNotificationsOn: false,
          createdAt: FieldValue.serverTimestamp(),
        });
      console.log("✅ Firestore entry created for:", userRecord.uid);
    } catch (e) {
      console.error("❌ Firestore error:", e);

      // Attempt rollback so you don't keep an orphaned Auth user
      try {
        await auth.deleteUser(userRecord.uid);
        console.log(
          "🧹 Rolled back auth user after Firestore failure:",
          userRecord.uid,
        );
      } catch (cleanupErr) {
        console.error("⚠️ Failed to clean up orphaned user:", cleanupErr);
      }

      throw new HttpsError(
        "internal",
        "User created, but failed to create profile document.",
      );
    }

    return { uid: userRecord.uid, email: userRecord.email };
  },
);
