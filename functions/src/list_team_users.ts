import { getFirestore } from "firebase-admin/firestore";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { logger } from "firebase-functions";
import { enforceCooldown, cooldownKeyFromCallable } from "./cooldown";

const db = getFirestore(); // fine if admin.initializeApp() was called

export const listTeamUsers = onCall(
  { cors: true, enforceAppCheck: true },
  async (req): Promise<string[]> => {
    // 1) Auth + role
    const uid = req.auth?.uid;
    if (!uid) throw new HttpsError("unauthenticated", "You must be signed in.");

    const userRole = req.auth?.token.role;
    if (userRole !== "teamAdmin") {
      throw new HttpsError("permission-denied", "Team admin only.");
    }

    // 2) Cooldown (10s/caller)
    const key = cooldownKeyFromCallable(req, "listTeamUsers");
    await enforceCooldown(key, 10);

    // 3) Query team emails
    const userTeam = req.auth?.token.team;
    if (!userTeam) {
      throw new HttpsError("failed-precondition", "User has no allocated team.");
    }

    try {
      const snap = await db
        .collection("user_data")
        .where("team", "==", userTeam)
        .select("email")
        .get();

      if (snap.empty) {
        logger.info("[listTeamUsers] No qualifying users.", { userTeam, uid });
        return [];
      }

      // Filter out any missing/empty emails, then sort
      const emails = snap.docs
        .map(d => d.get("email") as string | undefined)
        .filter((e): e is string => !!e && e.trim().length > 0)
        .sort((a, b) => a.localeCompare(b));

      logger.info("[listTeamUsers] Returned emails.", {
        userTeam,
        count: emails.length,
        uid,
      });

      return emails;
    } catch (err: any) {
      const code = err?.code; // gRPC code (9 for failed-precondition)
      const message = err?.message ?? String(err);

      // Try to pull out the Firestore "create index" console URL from the message
      const match = /https?:\/\/[^\s]+console[^)\s]+/i.exec(message);
      const indexUrl = match?.[0];

      logger.error("[listTeamUsers] Query failed.", {
        userTeam,
        uid,
        code,
        message,
        indexUrl: indexUrl ?? undefined,
      });

      // Optional: rethrow a clean error while still preserving logs above
      if (code === 9 && indexUrl) {
        // failed-precondition (missing index)
        throw new HttpsError(
          "failed-precondition",
          `Missing Firestore index. Create it here: ${indexUrl}`
        );
      }

      throw new HttpsError("internal", "Failed to list team users.");
    }
  }
);
