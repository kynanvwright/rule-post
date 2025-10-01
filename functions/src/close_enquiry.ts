import { getFirestore } from "firebase-admin/firestore";
import { onCall, HttpsError } from "firebase-functions/v2/https";

import { enforceCooldown, cooldownKeyFromCallable } from "./cooldown";

const db = getFirestore();

type DeleteUserPayload = { enquiryID: string };

export const closeEnquiry = onCall(
  { cors: true, enforceAppCheck: true },
  async (req) => {
    // 1) Check user is logged in and admin
    const callerUid = req.auth?.uid;
    if (!callerUid)
      throw new HttpsError("unauthenticated", "You must be signed in.");
    const isAdmin = req.auth?.token.role == "admin";
    const isRC = req.auth?.token.team == "RC";
    if (!isAdmin || !isRC) {
      throw new HttpsError("permission-denied", "Admin/RC function only.");
    }

    // 2) Enforce cooldown on function call
    await enforceCooldown(cooldownKeyFromCallable(req, "deleteUser"), 30);

    // 3) Close enquiry
    const { enquiryID } = req.data as DeleteUserPayload;
    await db.collection("enquiries").doc(enquiryID).update({
      isOpen: false,
      teamsCanRespond: false,
      teamsCanComment: false,
    });
    return { ok: true, enquiryID };
  },
);
