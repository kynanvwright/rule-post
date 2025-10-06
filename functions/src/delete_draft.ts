// functions/src/delete_drafts.ts
import { getFirestore } from "firebase-admin/firestore";
import { logger } from "firebase-functions";
import { HttpsError } from "firebase-functions/v2/https";

const db = getFirestore();

/**
 * Deletes a draft document for a given post ID and team.
 * Assumes caller has already passed authentication and authorization.
 */
export async function deleteDraft(id: string, team: string): Promise<void> {
  if (!id || !team) {
    throw new HttpsError("invalid-argument", "Missing id or team parameter");
  }

  try {
    const draftRef = db
      .collection("drafts")
      .doc("posts")
      .collection(team)
      .doc(id);
    const docSnap = await draftRef.get();

    if (!docSnap.exists) {
      logger.warn("⚠️ Draft record not found", { id, team });
      return;
    }

    await draftRef.delete();
    logger.info("✅ Firestore draft record deleted", { id, team });
  } catch (e: unknown) {
    const msg =
      typeof e === "object" && e !== null && "message" in e
        ? String((e as { message?: unknown }).message)
        : String(e);
    logger.error("❌ Firestore draft record delete failed", {
      id,
      team,
      error: msg,
    });
    throw new HttpsError("internal", "Firestore draft record delete failed");
  }
}
