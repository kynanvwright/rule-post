// ──────────────────────────────────────────────────────────────────────────────
// File: src/admin_funcs/close_enquiry.ts
// Purpose: Close enquiries, locking submission of any child posts
// ──────────────────────────────────────────────────────────────────────────────
import { getFirestore } from "firebase-admin/firestore";
import { onCall, HttpsError } from "firebase-functions/v2/https";

import { CloseEnquiryPayload } from "../common/types";

const db = getFirestore();

export const closeEnquiry = onCall(
  { cors: true, enforceAppCheck: true },
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
    const raw = (req.data as Partial<CloseEnquiryPayload>)?.enquiryID;
    if (typeof raw !== "string") {
      throw new HttpsError("invalid-argument", "enquiryID must be a string.");
    }
    const enquiryID = raw.trim();
    if (!enquiryID) {
      throw new HttpsError("invalid-argument", "enquiryID is required.");
    }
    if (enquiryID.includes("/")) {
      throw new HttpsError(
        "invalid-argument",
        "enquiryID must be a single segment (no slashes).",
      );
    }
    const enquiryConclusion = (req.data as Partial<CloseEnquiryPayload>)
      ?.enquiryConclusion;
    if (typeof enquiryConclusion !== "string") {
      throw new HttpsError(
        "invalid-argument",
        "enquiryConclusion must be a string.",
      );
    }

    // Optional: log for forensics (safe—doesn’t reveal secrets)
    console.log("[closeEnquiry] caller", {
      uid: callerUid,
      isAdmin,
      isRC,
      enquiryID,
      enquiryConclusion,
    });

    // 3) Update
    const ref = db.collection("enquiries").doc(enquiryID);
    // (Optional) ensure it exists first, for clearer errors:
    const snap = await ref.get();
    if (!snap.exists) {
      throw new HttpsError("not-found", `Enquiry ${enquiryID} does not exist.`);
    }

    await ref.update({
      isOpen: false,
      teamsCanRespond: false,
      teamsCanComment: false,
      enquiryConclusion: enquiryConclusion,
    });

    return { ok: true, enquiryID };
  },
);
