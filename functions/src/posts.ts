import {onCall, HttpsError, CallableRequest} from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import {randomUUID} from "node:crypto"; // no extra npm dep needed
import {File} from "@google-cloud/storage";
import {getFirestore} from "firebase-admin/firestore";

const ALLOWED_TYPES = [
  "application/pdf",
  // "image/.+",
  "application/vnd.openxmlformats-officedocument." +
    "wordprocessingml.document",
  "application/msword",
];
const ALLOWED_MIME = new RegExp(`^(${ALLOWED_TYPES.join("|")})$`, "i");
const MAX_BYTES = 25 * 1024 * 1024; // 25 MB cap for MVP

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
  file: File, message: string): Promise<never> {
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
  defaultIfMissingEverywhere = 0
): Promise<number> {
  const db = getFirestore();

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
  postType: string,
  title: string;
  postText?: string;
  attachments?: TempAttachmentIn[]; // <-- client sends temp entries
  parentIds?: string[]; // for responses/comments
};

export const createPost = onCall<CreatePostData>(
  async (req: CallableRequest<CreatePostData>) => {
    // auth check
    if (!req.auth?.uid) {
      throw new HttpsError("unauthenticated", "Sign in required.");
    }
    const authorUid = req.auth.uid;

    // ---- Parse + validate inputs ----
    const data = (req.data ?? {}) as CreatePostData;
    if (!data.postType ||
        (data.postType !== "enquiry" &&
            data.postType !== "response" &&
            data.postType !== "comment")) {
      throw new HttpsError("invalid-argument",
        "Invalid or missing postType.");
    }
    if (!data.postText && !data.attachments) {
      throw new HttpsError("invalid-argument",
        "Post must contain either text or an attachment.");
    }
    if (data.postType === "response" &&
      (!data.parentIds || data.parentIds.length !== 1)) {
      throw new HttpsError("invalid-argument",
        "Response must contain one parentId.");
    }
    if (data.postType === "comment" &&
      (!data.parentIds || data.parentIds.length !== 2)) {
      throw new HttpsError("invalid-argument",
        "Comment must contain two parentIds.");
    }
    if (data.postType === "comment" && !data.attachments) {
      throw new HttpsError("invalid-argument",
        "Comments must not have attachments.");
    }
    // declare inputs to variables
    const postType = data.postType;
    const title = String(data.title ?? "").trim();
    const postText = String(data.postText ?? "").trim();
    const parentIds = Array.isArray(data.parentIds) ? data.parentIds : [];

    // get references to services
    const db = admin.firestore();
    const bucket = admin.storage().bucket();

    // Pre-create an doc id so storage has a matching location
    let docRef;
    if (postType === "enquiry") {
      docRef = db.collection("enquiries").doc();
    } else if (postType === "response") {
      docRef = db.collection("enquiries").doc(parentIds[0])
        .collection("responses").doc();
    } else { // comment
      docRef = db.collection("enquiries").doc(parentIds[0])
        .collection("responses").doc(parentIds[1])
        .collection("comments").doc();
    }
    const postId = docRef.id;
    const postPath = docRef.path;

    // ---- Finalise attachments (optional) ----
    const incoming = Array.isArray(data.attachments) ? data.attachments : [];
    const finalised: FinalisedAttachment[] = [];

    for (const a of incoming) {
      const name = String(a?.name ?? "").trim();
      const tmpPath = String(a?.storagePath ?? "").trim();
      if (!name || !tmpPath) continue;

      // Enforce that the temp object belongs to the caller
      const expectedPrefix = `enquiries_temp/${authorUid}/`;
      if (!tmpPath.startsWith(expectedPrefix)) {
        throw new HttpsError("permission-denied", "Invalid attachment path.");
      }

      const srcFile = bucket.file(tmpPath);
      const [exists] = await srcFile.exists();
      if (!exists) {
        throw new HttpsError("not-found",
          `Temp attachment not found: ${tmpPath}`);
      }

      // Read server-side metadata (trust server, not client)
      const [md] = await srcFile.getMetadata();
      const size = Number(md.size ?? a.size ?? 0);
      const contentType = String(md.contentType ??
        a.contentType ?? "application/octet-stream");

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
        metadata: {firebaseStorageDownloadTokens: token},
      });

      const url = `https://firebasestorage.googleapis.com/v0/b/${bucket.name}/o/${encodeURIComponent(
        finalPath
      )}?alt=media&token=${token}`;

      finalised.push({name, url, size, contentType});
    }

    // ---- Write Firestore docs ----
    const now = admin.firestore.FieldValue.serverTimestamp();
    // const metaRef = db.collection("enquiries_meta").doc(enquiryId);

    const userData = await db.collection("user_data").doc(authorUid).get();
    if (!userData.exists) {
      throw new HttpsError("failed-precondition",
        "No matching user in the collection.");
    }
    const authorTeam = userData.get("team") as string;

    let enquiryNumber: number;
    let enquiryRoundNumber: number;
    let enquiryResponseNumber: number;
    if (postType === "enquiry") {
      const maxEnquiryNumber = await getMaxOrDefault(
        "enquiries", "enquiryNumber");
      enquiryNumber = maxEnquiryNumber + 1;
    } else if (postType === "response") {
      const enquiryDoc = await db.collection("enquiries")
        .doc(parentIds[0]).get();
      if (!enquiryDoc.exists) {
        throw new HttpsError("failed-precondition",
          "No matching enquiry for this response.");
      }
      enquiryRoundNumber = enquiryDoc.get("roundNumber") as number;
      // increment round number if user is the RC
      if (authorTeam === "RC") {
        enquiryRoundNumber += 1;
        enquiryResponseNumber = 0;
        // await db.collection("enquiries").doc(parentIds[0]).update({
        //     roundNumber: enquiryRoundNumber,
        // }); // update on publish not submission
      }
    }
    const isOpen = true; // future use
    const isPublished = false; // future use

    const result = await db.runTransaction(async (tx) => {
      const publicDoc: Record<string, unknown> = {
        title,
        postText,
        isPublished,
        publishedAt: now,
      };
      if (finalised.length > 0) {
        publicDoc.attachments = finalised;
      }
      if (postType === "enquiry") {
        publicDoc.isOpen = isOpen;
        publicDoc.enquiryNumber = enquiryNumber;
        publicDoc.roundNumber = 0;
        publicDoc.teamsCanRespond = true; // updated on response publish
        publicDoc.teamsCanComment = true; // updated on response publish
      } else if (postType === "response") {
        publicDoc.roundNumber = enquiryRoundNumber;
        publicDoc.responseNumber = enquiryResponseNumber; // set on publishing
      } else {
        // comment
      }

      // later add more checks here, e.g. has team responded?
      const metaDoc: Record<string, unknown> = {
        authorUid,
        authorTeam,
        createdAt: now,
      };

      tx.set(docRef, publicDoc);
      tx.set(docRef.collection("meta").doc("data"), metaDoc);

      return {id: postId};
    });

    return result;
  }
);
