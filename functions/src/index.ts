import {setGlobalOptions, logger} from "firebase-functions";
import {beforeUserCreated} from "firebase-functions/v2/identity";
import {onCall, HttpsError, CallableRequest} from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import {randomUUID} from "node:crypto"; // no extra npm dep needed
import {File} from "@google-cloud/storage";


/**
 * Global options for all functions.
 */
setGlobalOptions({
  region: "europe-west8",
  maxInstances: 10,
});

if (!admin.apps.length) {
  admin.initializeApp();
}

/** Block all self-registration */
export const blockAllSelfRegistration = beforeUserCreated(() => {
  throw new HttpsError(
    "permission-denied",
    "Self-registration is disabled.",
  );
});

const ALLOWED_TYPES = [
  "application/pdf",
  "image/.+",
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
type CreateEnquiryData = {
  titleText: string;
  enquiryText: string;
  attachments?: TempAttachmentIn[]; // <-- client sends temp entries
};


export const createEnquiry = onCall<CreateEnquiryData>(
  async (req: CallableRequest<CreateEnquiryData>) => {
    if (!req.auth?.uid) {
      throw new HttpsError("unauthenticated", "Sign in required.");
    }
    const authorUid = req.auth.uid;

    // ---- Parse + validate inputs ----
    const data = (req.data ?? {}) as CreateEnquiryData;
    const titleText = String(data.titleText ?? "").trim();
    const enquiryText = String(data.enquiryText ?? "").trim();
    if (!titleText || !enquiryText) {
      throw new HttpsError("invalid-argument",
        "titleText and enquiryText are required.");
    }

    const db = admin.firestore();
    const bucket = admin.storage().bucket();

    // Pre-create an enquiry id
    // so final storage can live under enquiries/{id}/...
    const docRef = db.collection("enquiries").doc();
    const enquiryId = docRef.id;

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
      const finalPath = `enquiries/${enquiryId}/${
        Date.now()}-${sanitiseName(name)}`;

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
    const metaRef = db.collection("enquiries_meta").doc(enquiryId);

    const result = await db.runTransaction(async (tx) => {
      const publicDoc: Record<string, unknown> = {
        titleText,
        enquiryText,
        createdAt: now,
      };
      if (finalised.length > 0) {
        publicDoc.attachments = finalised;
      }

      tx.set(docRef, publicDoc);
      tx.set(metaRef, {
        authorUid,
        authorEmail: null,
        createdAt: now,
        createdByProvider: null,
      });

      return {id: enquiryId};
    });

    return result; // { id }
  }
);


export const ping = onCall((req) => {
  logger.info("ping invoked", {
    hasAuth: !!req.auth,
    region: process.env.FUNCTION_REGION,
  });
  return {ok: true, ts: Date.now()};
});
