import { randomUUID } from "node:crypto"; // no extra npm dep needed

import { File } from "@google-cloud/storage";
import {
  getFirestore,
  FieldValue,
  DocumentSnapshot,
  DocumentReference,
} from "firebase-admin/firestore";
import { getStorage } from "firebase-admin/storage";
import {
  onCall,
  HttpsError,
  CallableRequest,
} from "firebase-functions/v2/https";

import { enforceCooldown, cooldownKeyFromCallable } from "./cooldown";
import { assignUniqueColoursForEnquiry } from "./post_colours";

const ALLOWED_TYPES = [
  "application/pdf",
  // "image/.+",
  "application/vnd.openxmlformats-officedocument." +
    "wordprocessingml.document",
  "application/msword",
];
const ALLOWED_MIME = new RegExp(`^(${ALLOWED_TYPES.join("|")})$`, "i");
const MAX_BYTES = 25 * 1024 * 1024; // 25 MB cap for MVP

function assert(cond: unknown, msg: string): asserts cond {
  if (!cond) throw new HttpsError("failed-precondition", msg);
}

/**
 * Lightweight filename sanitiser (keeps extensions).
 *
 * - Replaces disallowed characters with "_"
 * - Trims the result to 200 characters max
 *
 * @param {string} name Original filename
 * @return {string} Sanitised filename
 */
function sanitiseName(name: string): string {
  return name.replace(/[^\w.\-+]/g, "_").slice(0, 200);
}

/**
 * Attempts to delete a file, then always throws a precondition error.
 *
 * @param {File} file The GCS file to delete
 * @param {string} message Error message to throw
 * @throws {HttpsError} Always throws after attempting deletion
 * @return {never} This function never returns
 */
export async function deleteAndFail(
  file: File,
  message: string,
): Promise<never> {
  try {
    await file.delete();
  } catch {
    // ignore deletion errors
  }
  throw new HttpsError("failed-precondition", message);
}

/**
 * Returns the maximum numeric value of a given field in a Firestore collection.
 * If the field is missing from all documents, returns the provided default.
 *
 * @param {string} collectionPath - Path to the Firestore collection
 * @param {string} [field="value"] - Name of the field to search for max
 * @param {number} [defaultIfMissingEverywhere=1] - Returned if no matches
 * @return {Promise<number>} Resolves with the maximum value or the default
 * @throws {Error} If the Firestore query fails
 */
export async function getMaxOrDefault(
  collectionPath: string,
  field = "value",
  defaultIfMissingEverywhere = 0,
): Promise<number> {
  const db = getFirestore(); // should 'app' be passed in?

  const snap = await db
    .collection(collectionPath)
    .orderBy(field, "desc")
    .limit(1)
    .get();

  if (snap.empty) return defaultIfMissingEverywhere;

  const v = snap.docs[0].get(field);
  return typeof v === "number" ? v : defaultIfMissingEverywhere;
}

// What the client will send for each temp attachment
type TempAttachmentIn = {
  name: string; // display name (e.g., "diagram.png")
  storagePath: string; // e.g. "enquiries_temp/<uid>/123-diagram.png"
  size?: number; // optional; server re-reads from metadata anyway
  contentType?: string; // optional; server re-reads from metadata anyway
};

// What we store on the public enquiry doc
type FinalisedAttachment = {
  name: string;
  url: string; // tokenised download URL
  size?: number;
  contentType?: string;
};

// Payload shape for createEnquiry
type CreatePostData = {
  postType: string;
  title: string;
  postText?: string;
  attachments?: TempAttachmentIn[]; // <-- client sends temp entries
  parentIds?: string[]; // for responses/comments
};

export const createPost = onCall<CreatePostData>(
  { cors: true, enforceAppCheck: true },
  async (req: CallableRequest<CreatePostData>) => {
    // auth check
    if (!req.auth?.uid) {
      throw new HttpsError("unauthenticated", "Sign in required.");
    }
    const authorUid = req.auth.uid;
    // Enforce cooldown (e.g., 60s per caller for createPost)
    const key = cooldownKeyFromCallable(req, "createPost");
    await enforceCooldown(key, 10);

    // ---- Parse + validate inputs ----
    const data = (req.data ?? {}) as CreatePostData;
    if (
      !data.postType ||
      (data.postType !== "enquiry" &&
        data.postType !== "response" &&
        data.postType !== "comment")
    ) {
      throw new HttpsError("invalid-argument", "Invalid or missing postType.");
    }
    if (!data.postText && !data.attachments) {
      throw new HttpsError(
        "invalid-argument",
        "Post must contain either text or an attachment.",
      );
    }
    if (
      data.postType === "response" &&
      (!data.parentIds || data.parentIds.length !== 1)
    ) {
      throw new HttpsError(
        "invalid-argument",
        "Response must contain one parentId.",
      );
    }
    if (
      data.postType === "comment" &&
      (!data.parentIds || data.parentIds.length !== 2)
    ) {
      throw new HttpsError(
        "invalid-argument",
        "Comment must contain two parentIds.",
      );
    }
    if (
      data.postType === "comment" &&
      Array.isArray(data.attachments) &&
      data.attachments.length > 0
    ) {
      throw new HttpsError(
        "invalid-argument",
        "Comments must not have attachments.",
      );
    }
    // declare inputs to variables
    const postType = data.postType;
    const title = String(data.title ?? "").trim();
    const postText = String(data.postText ?? "").trim();
    const parentIds = Array.isArray(data.parentIds) ? data.parentIds : [];

    // get references to services
    const db = getFirestore(); // should 'app' be passed in?
    const bucket = getStorage().bucket();

    // Pre-create an doc id so storage has a matching location
    let docRef;
    if (postType === "enquiry") {
      docRef = db.collection("enquiries").doc();
    } else if (postType === "response") {
      docRef = db
        .collection("enquiries")
        .doc(parentIds[0])
        .collection("responses")
        .doc();
    } else {
      // comment
      docRef = db
        .collection("enquiries")
        .doc(parentIds[0])
        .collection("responses")
        .doc(parentIds[1])
        .collection("comments")
        .doc();
    }
    const postId = docRef.id;
    const postPath = docRef.path;

    // ---- Finalise attachments (optional) ----
    const incoming = Array.isArray(data.attachments) ? data.attachments : [];
    const finalised: FinalisedAttachment[] = [];

    const tempRoot =
      postType === "enquiry"
        ? "enquiries_temp"
        : postType === "response"
          ? "responses_temp"
          : "comments_temp";

    for (const a of incoming) {
      const name = String(a?.name ?? "").trim();
      const tmpPath = String(a?.storagePath ?? "").trim();
      if (!name || !tmpPath) continue;

      // Enforce that the temp object belongs to the caller
      const expectedPrefix = `${tempRoot}/${authorUid}/`;
      if (!tmpPath.startsWith(expectedPrefix)) {
        throw new HttpsError("permission-denied", "Invalid attachment path.");
      }

      const srcFile = bucket.file(tmpPath);
      const [exists] = await srcFile.exists();
      if (!exists) {
        throw new HttpsError(
          "not-found",
          `Temp attachment not found: ${tmpPath}`,
        );
      }

      // Read server-side metadata (trust server, not client)
      const [md] = await srcFile.getMetadata();
      const size = Number(md.size ?? a.size ?? 0);
      const contentType = String(
        md.contentType ?? a.contentType ?? "application/octet-stream",
      );

      if (size > MAX_BYTES) {
        await deleteAndFail(srcFile, "Attachment too large.");
      }

      if (!ALLOWED_MIME.test(contentType)) {
        await deleteAndFail(srcFile, "Unsupported attachment type.");
      }

      // Build final path under the new enquiry id
      const finalPath = postPath + "/" + sanitiseName(name);

      // Move temp -> final (move = copy+delete)
      await srcFile.move(finalPath);

      const file = bucket.file(finalPath);

      // Add a download token and persist contentType
      const token = randomUUID();
      await file.setMetadata({
        contentType,
        metadata: { firebaseStorageDownloadTokens: token },
      });

      const url = `https://firebasestorage.googleapis.com/v0/b/${bucket.name}/o/${encodeURIComponent(
        finalPath,
      )}?alt=media&token=${token}`;

      finalised.push({ name, url, size, contentType });
    }

    // ---- Write Firestore docs ----
    const now = FieldValue.serverTimestamp();

    const authorTeam = req.auth.token.team;
    if (typeof authorTeam !== "string" || authorTeam.length === 0) {
      throw new HttpsError(
        "failed-precondition",
        "No team assigned to this user.",
      );
    }

    let enquiryNumber: number;
    let enquiryRoundNumber: number;
    let enquiryResponseNumber: number | null;
    let enquiryDoc: DocumentSnapshot | null;
    let postColourMap: Record<string, string> | null = null;
    let postColour: string | null = null;
    if (postType === "enquiry") {
      const maxEnquiryNumber = await getMaxOrDefault(
        "enquiries",
        "enquiryNumber",
      );
      enquiryNumber = maxEnquiryNumber + 1;
      postColourMap = await assignUniqueColoursForEnquiry(postId);
    } else {
      enquiryDoc = await db.collection("enquiries").doc(parentIds[0]).get();
      if (!enquiryDoc.exists) {
        throw new HttpsError(
          "failed-precondition",
          "No matching enquiry for this response.",
        );
      }
      enquiryRoundNumber = enquiryDoc.get("roundNumber") as number;
      // increment round number if user is the RC
      if (authorTeam === "RC") {
        enquiryRoundNumber += 1;
        enquiryResponseNumber = 0;
      } else {
        enquiryResponseNumber = null;
      }
      // Assign post colour based on team
      const enquiryMetaDoc = await enquiryDoc.ref
        .collection("meta")
        .doc("data")
        .get();
      assert(enquiryMetaDoc, "enquiries/{id}/meta/data not found");
      const map = enquiryMetaDoc.get("teamColourMap") as
        | Record<string, string>
        | undefined;
      if (map) {
        postColour = map[authorTeam];
      } else {
        throw new HttpsError(
          "failed-precondition",
          "Team colour map not retrieved/interpreted correctly.",
        );
      }
    }
    const isOpen = true; // future use
    const isPublished = false; // future use
    const fromRC = authorTeam === "RC";

    const result = await db.runTransaction(async (tx) => {
      const publicDoc: Record<string, unknown> = {
        title,
        postText,
        isPublished,
        fromRC,
      };
      if (finalised.length > 0) {
        publicDoc.attachments = finalised;
      }
      if (postType === "enquiry") {
        publicDoc.isOpen = isOpen;
        publicDoc.enquiryNumber = enquiryNumber;
        publicDoc.roundNumber = 1;
        publicDoc.teamsCanRespond = true; // updated on response publish
        publicDoc.teamsCanComment = false; // updated on response publish
        publicDoc.stageLength = 4; // working days
      } else if (postType === "response") {
        if (!enquiryDoc) {
          throw new HttpsError(
            "failed-precondition",
            "No matching enquiry for this response.",
          );
        } else {
          const isOpen = enquiryDoc.get("isOpen");
          if (isOpen !== true) {
            throw new HttpsError("failed-precondition", "Enquiry is closed.");
          }
          // Locks duplicate submissions. Relax later to allow edits
          const teamsCanRespond = enquiryDoc.get("teamsCanRespond");
          if (fromRC !== true && teamsCanRespond !== true) {
            throw new HttpsError(
              "failed-precondition",
              "Competitors not permitted to respond at this time.",
            );
          }
          const respSnap = await db
            .collection("enquiries")
            .doc(parentIds[0])
            .collection("responses")
            .where("isPublished", "==", false)
            .get();
          if (!respSnap.empty) {
            const metaRefs: DocumentReference[] = respSnap.docs.map((d) =>
              d.ref.collection("meta").doc("data"),
            );

            const metaDocs = await db.getAll(...metaRefs);

            for (const m of metaDocs) {
              if (!m.exists) continue;
              const team = m.get("authorTeam") as string | undefined;
              if (team === authorTeam) {
                throw new HttpsError(
                  "failed-precondition",
                  "Only one response allowed per team per round.",
                );
              }
            }
          }
        }
        publicDoc.roundNumber = enquiryRoundNumber;
        publicDoc.responseNumber = enquiryResponseNumber; // set on publishing
        assert(postColour, "Post colour not populated for assignment.");
        publicDoc.colour = postColour;
      } else {
        if (!enquiryDoc) {
          throw new HttpsError(
            "failed-precondition",
            "No matching enquiry for this comment.",
          );
        } else {
          const isOpen = enquiryDoc.get("isOpen");
          if (isOpen !== true) {
            throw new HttpsError("failed-precondition", "Enquiry is closed.");
          }
          const teamsCanComment = enquiryDoc.get("teamsCanComment");
          if (fromRC !== true && teamsCanComment !== true) {
            throw new HttpsError(
              "failed-precondition",
              "Competitors not permitted to comment at this time.",
            );
          }
          const responseDoc = await db
            .collection("enquiries")
            .doc(parentIds[0])
            .collection("responses")
            .doc(parentIds[1])
            .get();
          const responseRound = responseDoc.get("roundNumber");
          const enquiryRound = enquiryDoc.get("roundNumber");
          if (responseRound !== enquiryRound) {
            throw new HttpsError(
              "failed-precondition",
              "Comments can only be made on the latest round of responses.",
            );
          }
          publicDoc.colour = postColour;
          // consider blocking comments on RC responses
        }
      }

      const metaDoc: Record<string, unknown> = {
        authorUid,
        authorTeam,
        createdAt: now,
      };
      if (postType === "enquiry") {
        metaDoc.teamColourMap = postColourMap;
      }

      tx.set(docRef, publicDoc);
      tx.set(docRef.collection("meta").doc("data"), metaDoc);

      return { id: postId };
    });

    return result;
  },
);
