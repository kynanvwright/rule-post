// ──────────────────────────────────────────────────────────────────────────────
// File: src/common/rate_limit.ts
// Purpose: Rate limiting for user submissions and admin functions
// ──────────────────────────────────────────────────────────────────────────────
import { getFirestore, FieldValue } from "firebase-admin/firestore";
import { logger } from "firebase-functions";
import { HttpsError } from "firebase-functions/v2/https";

const SUBMISSION_COOLDOWN_SECONDS = 10;
const ADMIN_THROTTLE_SECONDS = 5; // Admin calls must be 5+ seconds apart

/**
 * Check if user has exceeded cooldown before creating a post.
 * Updates last submission timestamp if allowed.
 *
 * @param userId The user creating the post
 * @throws HttpsError with 429 status if on cooldown
 */
export async function checkAndIncrementRateLimit(
  userId: string,
): Promise<void> {
  const db = getFirestore();
  const rateLimitRef = db.doc(`ratelimit/users/${userId}`);
  const now = Math.floor(Date.now() / 1000); // Unix seconds

  // Transactional check-and-set
  await db.runTransaction(async (tx) => {
    const snap = await tx.get(rateLimitRef);

    if (snap.exists) {
      const lastSubmission = snap.get("lastSubmissionAt") as number | undefined;

      if (
        lastSubmission &&
        now - lastSubmission < SUBMISSION_COOLDOWN_SECONDS
      ) {
        const secondsLeft = Math.ceil(
          SUBMISSION_COOLDOWN_SECONDS - (now - lastSubmission),
        );
        throw new HttpsError(
          "resource-exhausted",
          `Rate limited. Please wait ${secondsLeft} second${secondsLeft === 1 ? "" : "s"} before submitting again.`,
        );
      }
    }

    // Update last submission timestamp
    tx.set(rateLimitRef, { lastSubmissionAt: now }, { merge: true });
  });
}

/**
 * Throttle admin/RC function calls to prevent bulk enumeration attacks.
 * Enforces 1 call per 5 seconds per user and alerts on abuse patterns.
 *
 * @param userId The admin/RC user calling the function
 * @param functionName Name of the admin function for logging
 * @throws HttpsError with 429 status if too frequent
 * @returns { allowed: boolean; abuseAlert: boolean }
 */
export async function throttleAdminFunction(
  userId: string,
  functionName: string,
): Promise<{ allowed: boolean; abuseAlert: boolean }> {
  const db = getFirestore();
  const throttleRef = db.doc(`ratelimit/admin/${userId}`);
  const now = Math.floor(Date.now() / 1000);

  let abuseAlert = false;

  // Transactional check-and-update
  await db.runTransaction(async (tx) => {
    const snap = await tx.get(throttleRef);

    if (snap.exists) {
      const lastCallAt = snap.get("lastCallAt") as number | undefined;
      const callsInLastMinute = snap.get("callsInLastMinute") ?? 0;
      const minuteWindow = snap.get("minuteWindowStart") as number | undefined;

      // Check if within 5-second throttle window
      if (lastCallAt && now - lastCallAt < ADMIN_THROTTLE_SECONDS) {
        throw new HttpsError(
          "resource-exhausted",
          `Throttled. Please wait ${ADMIN_THROTTLE_SECONDS} seconds between calls.`,
        );
      }

      // Track calls per minute for abuse detection
      let newCallCount = callsInLastMinute + 1;
      let newMinuteStart = minuteWindow ?? now;

      // Reset minute window if expired
      if (!minuteWindow || now - minuteWindow >= 60) {
        newCallCount = 1;
        newMinuteStart = now;
      }

      // Alert if >5 calls/minute (abuse pattern)
      if (newCallCount > 5) {
        abuseAlert = true;
        logger.warn("[ABUSE_ALERT] Admin function spam detected", {
          userId,
          functionName,
          callsInLastMinute: newCallCount,
          timestamp: new Date().toISOString(),
        });
      }

      // Update throttle record
      tx.set(
        throttleRef,
        {
          lastCallAt: now,
          callsInLastMinute: newCallCount,
          minuteWindowStart: newMinuteStart,
          lastFunction: functionName,
        },
        { merge: true },
      );
    } else {
      // First call from this user
      tx.set(throttleRef, {
        lastCallAt: now,
        callsInLastMinute: 1,
        minuteWindowStart: now,
        lastFunction: functionName,
      });
    }
  });

  return { allowed: true, abuseAlert };
}

/**
 * Rate limit user creation by team admin.
 * Enforces per-admin limits (5/hour, 15/day) and per-team safety valve (50 ever).
 *
 * @param adminUid The team admin creating the user
 * @param teamName The team this admin belongs to
 * @throws HttpsError with 429 if limits exceeded
 */
export async function checkUserCreationRateLimit(
  adminUid: string,
  teamName: string,
): Promise<void> {
  const db = getFirestore();
  const now = Math.floor(Date.now() / 1000);

  // Check 1: Per-admin hourly limit (5 users/hour)
  const adminHourRef = db.doc(
    `ratelimit/admin_user_creation/${adminUid}/hourly/current`,
  );
  const adminDayRef = db.doc(
    `ratelimit/admin_user_creation/${adminUid}/daily/current`,
  );
  const teamRef = db.doc(`ratelimit/team_user_creation/${teamName}`);

  await db.runTransaction(async (tx) => {
    const [adminHourSnap, adminDaySnap, teamSnap] = await Promise.all([
      tx.get(adminHourRef),
      tx.get(adminDayRef),
      tx.get(teamRef),
    ]);

    // --- Per-admin hourly check (5/hour) ---
    let hourlyCount = 0;
    let hourlyWindowStart = now;

    if (adminHourSnap.exists) {
      const windowStart = adminHourSnap.get("windowStart") as
        | number
        | undefined;
      const count = adminHourSnap.get("count") ?? 0;

      if (windowStart && now - windowStart < 3600) {
        // Window still open
        hourlyCount = count;
        hourlyWindowStart = windowStart;
      } else {
        // Window expired, reset
        hourlyCount = 0;
        hourlyWindowStart = now;
      }
    }

    if (hourlyCount >= 5) {
      throw new HttpsError(
        "resource-exhausted",
        `User creation limit exceeded: 5 per hour. Try again in ${Math.ceil(3600 - (now - hourlyWindowStart))} seconds.`,
      );
    }

    // --- Per-admin daily check (15/day) ---
    let dailyCount = 0;
    let dailyWindowStart = now;

    if (adminDaySnap.exists) {
      const windowStart = adminDaySnap.get("windowStart") as number | undefined;
      const count = adminDaySnap.get("count") ?? 0;

      if (windowStart && now - windowStart < 86400) {
        // Window still open
        dailyCount = count;
        dailyWindowStart = windowStart;
      } else {
        // Window expired, reset
        dailyCount = 0;
        dailyWindowStart = now;
      }
    }

    if (dailyCount >= 15) {
      throw new HttpsError(
        "resource-exhausted",
        `User creation limit exceeded: 15 per day. Try again in ${Math.ceil(86400 - (now - dailyWindowStart))} seconds.`,
      );
    }

    // --- Per-team safety valve (50 total ever) ---
    let teamTotal = 0;

    if (teamSnap.exists) {
      teamTotal = teamSnap.get("totalUsersCreated") ?? 0;
    }

    if (teamTotal >= 50) {
      throw new HttpsError(
        "resource-exhausted",
        "Team has reached maximum user creation limit (50 total). Contact support to increase.",
      );
    }

    // All checks passed; increment counters
    tx.set(
      adminHourRef,
      {
        count: hourlyCount + 1,
        windowStart: hourlyWindowStart,
      },
      { merge: true },
    );

    tx.set(
      adminDayRef,
      {
        count: dailyCount + 1,
        windowStart: dailyWindowStart,
      },
      { merge: true },
    );

    tx.set(
      teamRef,
      {
        totalUsersCreated: teamTotal + 1,
        lastCreatedAt: FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
  });
}
