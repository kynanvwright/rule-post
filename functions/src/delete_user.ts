import { getAuth } from "firebase-admin/auth";
import { getFirestore } from "firebase-admin/firestore";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { enforceCooldown, cooldownKeyFromCallable } from "./cooldown";
import { logger } from "firebase-functions";

const auth = getAuth();
const db = getFirestore();

type DeleteUserPayload = { email: string };

async function resolveUidByEmail(emailRaw: string): Promise<string> {
  const email = emailRaw.trim().toLowerCase();
  try {
    const rec = await auth.getUserByEmail(email);
    return rec.uid;
  } catch (e: any) {
    // Fallback to Firestore mapping (in case Auth record is missing but a profile exists)
    if (e?.code === "auth/user-not-found") {
      const snap = await db.collection("user_data")
        .where("email", "==", email)
        .limit(1)
        .get();
      if (!snap.empty) return snap.docs[0].id;
      throw new HttpsError("not-found", "No user found with that email.");
    }
    throw new HttpsError("internal", `Auth lookup failed: ${e?.message || e}`);
  }
}

export const deleteUser = onCall(
  { cors: true, enforceAppCheck: true },
  async (req) => {
    // ── 1) Auth + role checks ────────────────────────────────────────────────
    const callerUid = req.auth?.uid;
    if (!callerUid) throw new HttpsError("unauthenticated", "You must be signed in.");

    const role = (req.auth?.token as any)?.role;
    if (role !== "teamAdmin") {
      throw new HttpsError("permission-denied", "Team admin only.");
    }

    // ── 2) Input + cooldown ─────────────────────────────────────────────────
    const { email } = (req.data ?? {}) as DeleteUserPayload;
    if (!email || typeof email !== "string" || !email.includes("@")) {
      throw new HttpsError("invalid-argument", "Missing or invalid email.");
    }

    await enforceCooldown(cooldownKeyFromCallable(req, "deleteUser"), 10);

    // ── 3) Resolve uid (Auth first, Firestore fallback) ─────────────────────
    const deletedUid = await resolveUidByEmail(email);

    // Prevent self-delete
    if (deletedUid === callerUid) {
      throw new HttpsError("failed-precondition", "You cannot delete your own account.");
    }

    logger.info("Deleting user", { deletedUid, email: email.trim().toLowerCase() });

    // ── 4) Delete from Auth ─────────────────────────────────────────────────
    try {
      await auth.deleteUser(deletedUid);
      logger.info("✅ Auth user deleted", { deletedUid });
    } catch (e: any) {
      logger.error("❌ Auth delete failed", { deletedUid, error: e?.message || e });
      throw new HttpsError("internal", "Failed to delete auth user.");
    }

    // ── 5) Delete Firestore profile doc (best-effort after Auth) ────────────
    try {
      await db.collection("user_data").doc(deletedUid).delete();
      logger.info("✅ Firestore profile deleted", { deletedUid });
    } catch (e: any) {
      // Auth deletion already succeeded; surface partial failure explicitly
      logger.error("❌ Firestore profile delete failed", { deletedUid, error: e?.message || e });
      throw new HttpsError(
        "internal",
        "Auth user deleted, but failed to delete Firestore profile document."
      );
    }

    return { ok: true, deletedUid };
  }
);
