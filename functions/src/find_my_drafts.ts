// functions/src/find_my_drafts.ts
import { getFirestore } from "firebase-admin/firestore";
import {
  onCall,
  CallableRequest,
  HttpsError,
} from "firebase-functions/v2/https";

const db = getFirestore();

// Payload shape for createEnquiry
type FindDraftsData = {
  postType: string;
  parentIds?: Array<string>;
};

// Minimal callable: returns an array of document IDs
export const findDrafts = onCall<FindDraftsData>(
  { enforceAppCheck: true },
  async (req: CallableRequest<FindDraftsData>) => {
    // 1) Auth check
    if (!req.auth?.uid) {
      throw new HttpsError("unauthenticated", "Sign in required.");
    }
    if (!req.auth?.token.team) {
      throw new HttpsError(
        "failed-precondition",
        "User is not correctly assigned to a team.",
      );
    }
    const userTeam = req.auth.token.team;

    // 2) Parse + validate inputs
    const data = (req.data ?? {}) as FindDraftsData;
    const validPostTypes = ["enquiry", "response", "comment"];
    if (!data.postType || !validPostTypes.includes(data.postType)) {
      throw new HttpsError("invalid-argument", "Invalid or missing postType.");
    }

    // 3) Read draft collection
    let q = db
      .collection("drafts")
      .doc("posts")
      .collection(userTeam)
      .where("postType", "==", data.postType);
    if (data.postType !== "enquiry") {
      q = q.where("parentIds", "==", data.parentIds);
    }

    // 4) Return results
    const snap = await q.select().get();
    return snap.docs.map((d) => d.id);
  },
);

// Minimal callable: returns an array of document IDs
export const hasDrafts = onCall<void>(
  { enforceAppCheck: true },
  async (req) => {
    // 1) Auth check
    if (!req.auth?.uid) {
      throw new HttpsError("unauthenticated", "Sign in required.");
    }
    if (!req.auth?.token.team) {
      throw new HttpsError(
        "failed-precondition",
        "User is not correctly assigned to a team.",
      );
    }
    const userTeam = req.auth.token.team;

    // 2) Query drafts collection for this team
    const draftsRef = db.collection("drafts").doc("posts").collection(userTeam);

    // 3) Check if any documents exist (limit to 1 for efficiency)
    const snap = await draftsRef.limit(1).get();

    // 4) Return true if collection exists *and* has documents
    return snap.size > 0;
  },
);
