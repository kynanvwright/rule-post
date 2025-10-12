// ──────────────────────────────────────────────────────────────────────────────
// File: src/admin_funcs/change_stage_length.ts
// Purpose: Change how long each submission stage stays open for (in days)
// ──────────────────────────────────────────────────────────────────────────────
import { getFirestore } from "firebase-admin/firestore";
import { onCall, HttpsError } from "firebase-functions/v2/https";

import { REGION, MEMORY, TIMEOUT_SECONDS } from "../common/config";
import { changeStageLengthPayload } from "../common/types";
import { offsetByWorkingDays } from "../utils/offset_by_working_days";

const db = getFirestore();

export const closeEnquiry = onCall(
  {
    region: REGION,
    cors: true,
    memory: MEMORY,
    timeoutSeconds: TIMEOUT_SECONDS,
    enforceAppCheck: true,
  },
  async (req) => {
    // 1) AuthZ
    const callerUid = req.auth?.uid;
    if (!callerUid) {
      throw new HttpsError("unauthenticated", "You must be signed in.");
    }
    const isAdmin = req.auth?.token.role === "admin";
    const isRC = req.auth?.token.team === "RC";
    if (!isAdmin && !isRC) {
      throw new HttpsError("permission-denied", "Admin/RC function only.");
    }

    // 2) Input validation
    const { enquiryID, newStageLength } = req.data as changeStageLengthPayload;
    const ref = db.collection("enquiries").doc(enquiryID);
    // (Optional) ensure it exists first, for clearer errors:
    const snap = await ref.get();
    if (!snap.exists) {
      throw new HttpsError("not-found", `Enquiry ${enquiryID} does not exist.`);
    }
    const oldStageLength = snap.get("stageLength");
    if (oldStageLength == newStageLength) {
      throw new HttpsError(
        "already-exists",
        `Enquiry already has stage length ${newStageLength}.`,
      );
    }

    // 3) Calculate new stage end
    const oldStageEnds = snap.get("stageEnds");
    const stageLengthDiff = newStageLength - oldStageLength;
    const stageEnds = offsetByWorkingDays(oldStageEnds, stageLengthDiff);

    // 4) Update
    await ref.update({
      stageLength: newStageLength,
      stageEnds: stageEnds,
    });

    return { ok: true };
  },
);
