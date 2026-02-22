// ──────────────────────────────────────────────────────────────────────────────
// File: src/admin_funcs/admin_manage_users.ts
// Purpose: Site-admin-only functions for managing all teams and users.
//   - adminListAllTeams: returns all teams with their members
//   - adminDeleteUser: deletes any user (Auth + Firestore) by UID
//   - adminToggleUserLock: disables or enables a user's Auth account
//   - adminDeleteTeam: deletes all users in a team
// ──────────────────────────────────────────────────────────────────────────────
import { getAuth } from "firebase-admin/auth";
import { getFirestore } from "firebase-admin/firestore";
import { logger } from "firebase-functions";
import { onCall, HttpsError } from "firebase-functions/v2/https";

import { deepDeleteDoc } from "../utils/deep_delete_doc";

const auth = getAuth();
const db = getFirestore();

/** Guard: caller must have role=admin */
function requireSiteAdmin(req: {
  auth?: { uid?: string; token?: Record<string, unknown> };
}): string {
  const uid = req.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "You must be signed in.");
  if (req.auth?.token?.role !== "admin") {
    throw new HttpsError("permission-denied", "Site admin only.");
  }
  return uid;
}

// ─────────────────────────────────────────────────────────────────────────────
// 1. List all teams and members
// ─────────────────────────────────────────────────────────────────────────────
export const adminListAllTeams = onCall(
  { cors: true, enforceAppCheck: true },
  async (req) => {
    requireSiteAdmin(req);

    const snap = await db.collection("user_data").get();

    // Group by team
    const teams: Record<
      string,
      Array<{
        uid: string;
        email: string;
        displayName: string;
        teamAdmin: boolean;
        disabled: boolean;
      }>
    > = {};

    // Batch-fetch Auth records for disabled status
    const uids = snap.docs.map((d) => d.id);
    const authLookup: Record<string, boolean> = {};

    // Firebase auth.getUsers accepts max 100 at a time
    for (let i = 0; i < uids.length; i += 100) {
      const batch = uids.slice(i, i + 100).map((uid) => ({ uid }));
      const result = await auth.getUsers(batch);
      for (const u of result.users) {
        authLookup[u.uid] = u.disabled ?? false;
      }
    }

    for (const doc of snap.docs) {
      const data = doc.data();
      const team = (data.team as string) || "UNASSIGNED";
      if (!teams[team]) teams[team] = [];

      const email = (data.email as string) || "";
      const displayName = (data.displayName as string) || "";
      const teamAdmin = (data.teamAdmin as boolean) || false;
      const disabled = authLookup[doc.id] ?? false;

      teams[team].push({
        uid: doc.id,
        email,
        displayName,
        teamAdmin,
        disabled,
      });
    }

    // Sort members within each team by email
    for (const team of Object.keys(teams)) {
      teams[team].sort((a, b) => a.email.localeCompare(b.email));
    }

    logger.info("adminListAllTeams", { teamCount: Object.keys(teams).length });
    return { teams };
  },
);

// ─────────────────────────────────────────────────────────────────────────────
// 2. Delete a user (any team)
// ─────────────────────────────────────────────────────────────────────────────
export const adminDeleteUser = onCall(
  { cors: true, enforceAppCheck: true },
  async (req) => {
    const callerUid = requireSiteAdmin(req);

    const { uid } = req.data as { uid: string };
    if (!uid || typeof uid !== "string") {
      throw new HttpsError("invalid-argument", "Missing uid.");
    }
    if (uid === callerUid) {
      throw new HttpsError("failed-precondition", "Cannot delete yourself.");
    }

    logger.info("adminDeleteUser", { uid });

    // Delete Auth user
    try {
      await auth.deleteUser(uid);
      logger.info("✅ Auth user deleted", { uid });
    } catch (e: unknown) {
      const msg = e instanceof Error ? e.message : String(e);
      logger.error("❌ Auth delete failed", { uid, error: msg });
      throw new HttpsError("internal", "Failed to delete auth user.");
    }

    // Delete Firestore profile (with subcollections)
    try {
      await deepDeleteDoc(db.collection("user_data").doc(uid));
      logger.info("✅ Firestore profile deleted", { uid });
    } catch (e: unknown) {
      const msg = e instanceof Error ? e.message : String(e);
      logger.error("❌ Firestore delete failed", { uid, error: msg });
      throw new HttpsError(
        "internal",
        "Auth user deleted but Firestore cleanup failed.",
      );
    }

    return { ok: true, uid };
  },
);

// ─────────────────────────────────────────────────────────────────────────────
// 3. Lock / unlock a user (disable/enable Auth account)
// ─────────────────────────────────────────────────────────────────────────────
export const adminToggleUserLock = onCall(
  { cors: true, enforceAppCheck: true },
  async (req) => {
    const callerUid = requireSiteAdmin(req);

    const { uid, disabled } = req.data as { uid: string; disabled: boolean };
    if (!uid || typeof uid !== "string") {
      throw new HttpsError("invalid-argument", "Missing uid.");
    }
    if (typeof disabled !== "boolean") {
      throw new HttpsError("invalid-argument", "Missing disabled flag.");
    }
    if (uid === callerUid) {
      throw new HttpsError("failed-precondition", "Cannot lock yourself.");
    }

    logger.info("adminToggleUserLock", { uid, disabled });

    await auth.updateUser(uid, { disabled });
    logger.info(`✅ User ${disabled ? "locked" : "unlocked"}`, { uid });

    // Persist to Firestore so client-side streams reflect the change
    try {
      await db.collection("user_data").doc(uid).update({ disabled });
    } catch (e: unknown) {
      const msg =
        typeof e === "object" && e !== null && "message" in e
          ? String((e as { message?: unknown }).message)
          : String(e);
      logger.warn("Firestore disabled-flag update failed", { uid, error: msg });
    }

    return { ok: true, uid, disabled };
  },
);

// ─────────────────────────────────────────────────────────────────────────────
// 4. Delete an entire team (all members)
// ─────────────────────────────────────────────────────────────────────────────
export const adminDeleteTeam = onCall(
  { cors: true, enforceAppCheck: true },
  async (req) => {
    const callerUid = requireSiteAdmin(req);

    const { team } = req.data as { team: string };
    if (!team || typeof team !== "string") {
      throw new HttpsError("invalid-argument", "Missing team.");
    }
    if (team === "RC") {
      throw new HttpsError(
        "failed-precondition",
        "The RC team cannot be deleted.",
      );
    }

    logger.info("adminDeleteTeam", { team });

    // Find all users in the team
    const snap = await db
      .collection("user_data")
      .where("team", "==", team)
      .get();

    if (snap.empty) {
      throw new HttpsError("not-found", `No users found in team ${team}.`);
    }

    const results: Array<{ uid: string; ok: boolean; error?: string }> = [];

    for (const doc of snap.docs) {
      const uid = doc.id;

      // Don't delete the caller
      if (uid === callerUid) {
        results.push({ uid, ok: false, error: "Cannot delete yourself." });
        continue;
      }

      try {
        await auth.deleteUser(uid);
        await deepDeleteDoc(db.collection("user_data").doc(uid));
        results.push({ uid, ok: true });
        logger.info("✅ Deleted team member", { uid, team });
      } catch (e: unknown) {
        const msg = e instanceof Error ? e.message : String(e);
        results.push({ uid, ok: false, error: msg });
        logger.error("❌ Failed to delete team member", {
          uid,
          team,
          error: msg,
        });
      }
    }

    const deleted = results.filter((r) => r.ok).length;
    const failed = results.filter((r) => !r.ok).length;

    return { ok: failed === 0, deleted, failed, results };
  },
);
