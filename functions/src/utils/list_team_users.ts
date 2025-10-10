import { getFirestore } from "firebase-admin/firestore";
import { logger } from "firebase-functions";
import { onCall, HttpsError } from "firebase-functions/v2/https";

const db = getFirestore(); // fine if admin.initializeApp() was called

export const listTeamUsers = onCall(
  { cors: true, enforceAppCheck: true },
  async (req): Promise<string[]> => {
    // 1) Auth + role
    const uid = req.auth?.uid;
    if (!uid) throw new HttpsError("unauthenticated", "You must be signed in.");

    const isTeamAdmin = req.auth?.token.teamAdmin;
    if (!isTeamAdmin) {
      throw new HttpsError("permission-denied", "Team admin only.");
    }

    // 2) Query team emails
    const userTeam = req.auth?.token.team;
    if (!userTeam) {
      throw new HttpsError(
        "failed-precondition",
        "User has no allocated team.",
      );
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
        .map((d) => d.get("email") as string | undefined)
        .filter((e): e is string => !!e && e.trim().length > 0)
        .sort((a, b) => a.localeCompare(b));

      logger.info("[listTeamUsers] Returned emails.", {
        userTeam,
        count: emails.length,
        uid,
      });

      return emails;
    } catch (err: unknown) {
      const code =
        typeof err === "object" && err !== null && "code" in err
          ? (err as { code?: unknown }).code
          : undefined;

      const message =
        typeof err === "object" && err !== null && "message" in err
          ? String((err as { message?: unknown }).message)
          : String(err);

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
          `Missing Firestore index. Create it here: ${indexUrl}`,
        );
      }

      throw new HttpsError("internal", "Failed to list team users.");
    }
  },
);
