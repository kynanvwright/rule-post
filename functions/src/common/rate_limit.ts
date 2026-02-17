// ──────────────────────────────────────────────────────────────────────────────
// File: src/common/rate_limit.ts
// Purpose: Per-user cooldown to prevent submission spam
// ──────────────────────────────────────────────────────────────────────────────
import { getFirestore } from "firebase-admin/firestore";
import { HttpsError } from "firebase-functions/v2/https";

const COOLDOWN_SECONDS = 10;

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

      if (lastSubmission && now - lastSubmission < COOLDOWN_SECONDS) {
        const secondsLeft = Math.ceil(
          COOLDOWN_SECONDS - (now - lastSubmission),
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
