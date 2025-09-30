import { getAuth } from "firebase-admin/auth";
import { getFirestore } from "firebase-admin/firestore";
import { logger } from "firebase-functions";
import { onCall, HttpsError } from "firebase-functions/v2/https";

import { enforceCooldown, cooldownKeyFromCallable } from "./cooldown";

const auth = getAuth();
const db = getFirestore();

type DeleteUserPayload = { email: string };

async function resolveUidByEmail(emailRaw: string): Promise<string> {
  const email = emailRaw.trim().toLowerCase();
  try {
    const rec = await auth.getUserByEmail(email);
    return rec.uid;
  } catch (e: unknown) {
    if (
      typeof e === "object" &&
      e !== null &&
      "code" in e &&
      (e as { code?: string }).code === "auth/user-not-found"
    ) {
      // Fallback to Firestore mapping
      const snap = await db
        .collection("user_data")
        .where("email", "==", email)
        .limit(1)
        .get();
      if (!snap.empty) return snap.docs[0].id;
      throw new HttpsError("not-found", "No user found with that email.");
    }
    const msg =
      typeof e === "object" && e !== null && "message" in e
        ? String((e as { message?: unknown }).message)
        : String(e);
    throw new HttpsError("internal", `Auth lookup failed: ${msg}`);
  }
}

export const deleteUser = onCall(
  { cors: true, enforceAppCheck: true },
  async (req) => {
    const callerUid = req.auth?.uid;
    if (!callerUid)
      throw new HttpsError("unauthenticated", "You must be signed in.");

    const role = (req.auth?.token as { role?: string })?.role;
    if (role !== "teamAdmin") {
      throw new HttpsError("permission-denied", "Team admin only.");
    }

    const { email } = (req.data ?? {}) as DeleteUserPayload;
    if (!email || typeof email !== "string" || !email.includes("@")) {
      throw new HttpsError("invalid-argument", "Missing or invalid email.");
    }

    await enforceCooldown(cooldownKeyFromCallable(req, "deleteUser"), 10);

    const deletedUid = await resolveUidByEmail(email);

    if (deletedUid === callerUid) {
      throw new HttpsError(
        "failed-precondition",
        "You cannot delete your own account.",
      );
    }

    logger.info("Deleting user", { deletedUid, email });

    try {
      await auth.deleteUser(deletedUid);
      logger.info("✅ Auth user deleted", { deletedUid });
    } catch (e: unknown) {
      const msg =
        typeof e === "object" && e !== null && "message" in e
          ? String((e as { message?: unknown }).message)
          : String(e);
      logger.error("❌ Auth delete failed", { deletedUid, error: msg });
      throw new HttpsError("internal", "Failed to delete auth user.");
    }

    try {
      await db.collection("user_data").doc(deletedUid).delete();
      logger.info("✅ Firestore profile deleted", { deletedUid });
    } catch (e: unknown) {
      const msg =
        typeof e === "object" && e !== null && "message" in e
          ? String((e as { message?: unknown }).message)
          : String(e);
      logger.error("❌ Firestore profile delete failed", {
        deletedUid,
        error: msg,
      });
      throw new HttpsError(
        "internal",
        "Auth user deleted, but failed to delete Firestore profile document.",
      );
    }

    return { ok: true, deletedUid };
  },
);
