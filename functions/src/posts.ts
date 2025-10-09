import { File } from "@google-cloud/storage";
import { getFirestore, FieldValue } from "firebase-admin/firestore";
import { getStorage } from "firebase-admin/storage";
import {
  onCall,
  HttpsError,
  CallableRequest,
} from "firebase-functions/v2/https";

import { assignUniqueColoursForEnquiry } from "./post_colours";

/* --------------------------------- Config --------------------------------- */

const ALLOWED_TYPES = [
  "application/pdf",
  "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
  "application/msword",
];
const ALLOWED_MIME = new RegExp(`^(${ALLOWED_TYPES.join("|")})$`, "i");
const MAX_BYTES = 25 * 1024 * 1024; // 25 MB

/* -------------------------------- Utilities ------------------------------- */

function assert(cond: unknown, msg: string): asserts cond {
  if (!cond) throw new HttpsError("failed-precondition", msg);
}

/** Lightweight filename sanitiser (keeps extensions). */
function sanitiseName(name: string): string {
  return String(name)
    .replace(/[^\w.\-+]/g, "_")
    .slice(0, 200);
}

/**
 * Type guard for Google Cloud Storage errors.
 * Returns true if the given value is an object with `code === 404`,
 * which indicates a "Not Found" error from GCS.
 *
 * This avoids using `any` and keeps ESLint (`no-explicit-any`, `no-unsafe-member-access`)
 * fully satisfied while handling storage errors safely.
 */
function isNotFoundError(e: unknown): boolean {
  return (
    typeof e === "object" &&
    e !== null &&
    "code" in e &&
    (e as { code?: number }).code === 404
  );
}

/** Delete a file then always fail with a clean error. */
async function deleteAndFail(file: File, message: string): Promise<never> {
  try {
    await file.delete();
  } catch {
    /* ignore */
  }
  throw new HttpsError("failed-precondition", message);
}

/* --------------------------------- Types ---------------------------------- */

type TempAttachmentIn = {
  name: string;
  storagePath: string;
  size?: number;
  contentType?: string;
};

type FinalisedAttachment = {
  name: string;
  path: string;
  size?: number;
  contentType?: string;
};

type CreatePostData = {
  postType: "enquiry" | "response" | "comment";
  title?: string;
  postText?: string;
  attachments?: TempAttachmentIn[];
  parentIds?: string[]; // response: [enquiryId], comment: [enquiryId, responseId]
};

/* ------------------------------- Main Logic -------------------------------- */

export const createPost = onCall<CreatePostData>(
  { enforceAppCheck: true },
  async (req: CallableRequest<CreatePostData>) => {
    /* ----------------------------- Auth & Inputs ----------------------------- */
    if (!req.auth?.uid)
      throw new HttpsError("unauthenticated", "Sign in required.");
    const authorUid = req.auth.uid;
    const authorTeam = req.auth.token.team;
    if (typeof authorTeam !== "string" || authorTeam.length === 0) {
      throw new HttpsError(
        "failed-precondition",
        "No team assigned to this user.",
      );
    }

    const data = (req.data ?? {}) as CreatePostData;
    if (
      !data.postType ||
      !["enquiry", "response", "comment"].includes(data.postType)
    ) {
      throw new HttpsError("invalid-argument", "Invalid or missing postType.");
    }
    const postType = data.postType;

    const title = String(data.title ?? "").trim();
    const postText = String(data.postText ?? "").trim();

    if (
      postType !== "comment" &&
      !postText &&
      !Array.isArray(data.attachments)
    ) {
      throw new HttpsError(
        "invalid-argument",
        "Post must contain either text or an attachment.",
      );
    }

    const parentIds = Array.isArray(data.parentIds) ? data.parentIds : [];
    if (postType === "response" && parentIds.length !== 1) {
      throw new HttpsError(
        "invalid-argument",
        "Response must contain one parentId.",
      );
    }
    if (postType === "comment") {
      if (parentIds.length !== 2) {
        throw new HttpsError(
          "invalid-argument",
          "Comment must contain two parentIds.",
        );
      }
      if (Array.isArray(data.attachments) && data.attachments.length > 0) {
        throw new HttpsError(
          "invalid-argument",
          "Comments must not have attachments.",
        );
      }
    }

    const db = getFirestore();
    const bucket = getStorage().bucket();

    /* -------------------------- Pre-create docRef ---------------------------- */
    const docRef =
      postType === "enquiry"
        ? db.collection("enquiries").doc()
        : postType === "response"
          ? db
              .collection("enquiries")
              .doc(parentIds[0])
              .collection("responses")
              .doc()
          : db
              .collection("enquiries")
              .doc(parentIds[0])
              .collection("responses")
              .doc(parentIds[1])
              .collection("comments")
              .doc();

    const postId = docRef.id;
    const postPath = docRef.path;

    /* ------------------- Validate attachments (no moves yet) ----------------- */
    const incoming = Array.isArray(data.attachments) ? data.attachments : [];
    const validatedAttachments: FinalisedAttachment[] = [];

    if (postType !== "comment" && incoming.length > 0) {
      const tempRoot =
        postType === "enquiry"
          ? "enquiries_temp"
          : postType === "response"
            ? "responses_temp"
            : "comments_temp";

      const expectedPrefix = `${tempRoot}/${authorUid}/`;

      for (const a of incoming) {
        const name = sanitiseName(String(a?.name ?? "").trim());
        const tmpPath = String(a?.storagePath ?? "").trim();
        if (!name || !tmpPath) continue;

        if (!tmpPath.startsWith(expectedPrefix)) {
          throw new HttpsError("permission-denied", "Invalid attachment path.");
        }

        const srcFile = bucket.file(tmpPath);

        const [md] = await srcFile.getMetadata().catch((e: unknown) => {
          if (isNotFoundError(e)) {
            throw new HttpsError(
              "not-found",
              `Temp attachment not found: ${tmpPath}`,
            );
          }
          throw e;
        });

        const size = Number(md.size ?? a.size ?? 0);
        const contentType = String(
          md.contentType ?? a.contentType ?? "application/octet-stream",
        );

        if (size > MAX_BYTES)
          await deleteAndFail(srcFile, "Attachment too large.");
        if (!ALLOWED_MIME.test(contentType))
          await deleteAndFail(srcFile, "Unsupported attachment type.");

        const finalPath = `${postPath}/${name}`;
        validatedAttachments.push({ name, path: finalPath, size, contentType });
      }
    }

    /* -------------------------- Perform transaction -------------------------- */
    const result = await db.runTransaction(async (tx) => {
      const now = FieldValue.serverTimestamp();
      const isPublished = false;
      const fromRC = authorTeam === "RC";

      const publicDoc: Record<string, unknown> = { isPublished, fromRC };
      if (title) publicDoc.title = title;
      if (postText) publicDoc.postText = postText;
      // attachments added after storage copies succeed

      if (postType === "enquiry") {
        // 1) atomic counter for enquiryNumber
        const countersRef = db.collection("app_data").doc("counters");
        const countersSnap = await tx.get(countersRef);
        const current = countersSnap.exists
          ? Number(countersSnap.get("enquiryNumber") ?? 0)
          : 0;
        const next = current + 1;
        tx.set(countersRef, { enquiryNumber: next }, { merge: true });

        // 2) compute private team colours, keep them in meta only
        const colourMap = await assignUniqueColoursForEnquiry(postId);

        Object.assign(publicDoc, {
          isOpen: true,
          enquiryNumber: next,
          roundNumber: 1,
          teamsCanRespond: true, // toggled later by RC publish
          teamsCanComment: false, // toggled later by RC publish
          stageLength: 4,
        });

        // Write public + meta
        tx.set(docRef, publicDoc);
        tx.set(docRef.collection("meta").doc("data"), {
          authorUid,
          authorTeam, // PRIVATE
          createdAt: now,
          teamColourMap: colourMap ?? {}, // PRIVATE
        });
      } else {
        // Non-enquiry: read parent enquiry + private meta inside TX
        const enquiryRef = db.collection("enquiries").doc(parentIds[0]);
        const enquirySnap = await tx.get(enquiryRef);
        if (!enquirySnap.exists) {
          throw new HttpsError(
            "failed-precondition",
            "No matching enquiry found.",
          );
        }

        const enquiryIsOpen = enquirySnap.get("isOpen") === true;
        if (!enquiryIsOpen)
          throw new HttpsError("failed-precondition", "Enquiry is closed.");

        const roundNumber = Number(enquirySnap.get("roundNumber") || 0);

        // Private meta (for colours, etc.)
        const enquiryMetaRef = enquiryRef.collection("meta").doc("data");
        const enquiryMetaSnap = await tx.get(enquiryMetaRef);
        if (!enquiryMetaSnap.exists) {
          throw new HttpsError(
            "failed-precondition",
            "Enquiry meta not found.",
          );
        }
        const teamColourMap = (enquiryMetaSnap.get("teamColourMap") ||
          {}) as Record<string, string>;

        if (postType === "response") {
          if (
            authorTeam !== "RC" &&
            enquirySnap.get("teamsCanRespond") !== true
          ) {
            throw new HttpsError(
              "failed-precondition",
              "Competitors not permitted to respond at this time.",
            );
          }

          // PRIVATE uniqueness guard: one response per team per round
          const guardRef = enquiryRef
            .collection("meta")
            .doc("response_guards") // a doc so the subcollection is private under meta
            .collection("guards")
            .doc(`${authorTeam}_${roundNumber}`);

          tx.create(guardRef, { authorTeam, roundNumber, createdAt: now });

          publicDoc.roundNumber =
            authorTeam === "RC" ? roundNumber + 1 : roundNumber;

          // Resolve colour privately
          if (authorTeam === "RC") {
            const wheelSnap = await tx.get(
              db.collection("app_data").doc("colour_wheel"),
            );
            if (!wheelSnap.exists)
              throw new HttpsError(
                "failed-precondition",
                "Colour wheel not configured.",
              );
            publicDoc.colour = wheelSnap.get("grey");
          } else {
            const c = teamColourMap?.[authorTeam];
            if (!c)
              throw new HttpsError(
                "failed-precondition",
                "Team colour not found.",
              );
            publicDoc.colour = c;
          }
        }

        if (postType === "comment") {
          if (
            authorTeam !== "RC" &&
            enquirySnap.get("teamsCanComment") !== true
          ) {
            throw new HttpsError(
              "failed-precondition",
              "Competitors not permitted to comment at this time.",
            );
          }

          const respRef = enquiryRef.collection("responses").doc(parentIds[1]);
          const respSnap = await tx.get(respRef);
          if (!respSnap.exists)
            throw new HttpsError("failed-precondition", "Response not found.");

          if (respSnap.get("fromRC") === true) {
            throw new HttpsError(
              "failed-precondition",
              "Comments can only be made on Competitor responses.",
            );
          }
          const respRound = Number(respSnap.get("roundNumber") || 0);
          if (respRound !== roundNumber) {
            throw new HttpsError(
              "failed-precondition",
              "Comments must target the latest round.",
            );
          }

          // Resolve colour privately
          if (authorTeam === "RC") {
            const wheelSnap = await tx.get(
              db.collection("app_data").doc("colour_wheel"),
            );
            if (!wheelSnap.exists)
              throw new HttpsError(
                "failed-precondition",
                "Colour wheel not configured.",
              );
            publicDoc.colour = wheelSnap.get("grey");
          } else {
            const c = teamColourMap?.[authorTeam];
            if (!c)
              throw new HttpsError(
                "failed-precondition",
                "Team colour not found.",
              );
            publicDoc.colour = c;
          }
        }

        // Write public + meta
        tx.set(docRef, publicDoc);
        tx.set(docRef.collection("meta").doc("data"), {
          authorUid,
          authorTeam, // PRIVATE
          createdAt: now,
        });
      }

      // Draft (kept in tx for atomicity)
      const draftRef = db
        .collection("drafts")
        .doc("posts")
        .collection(authorTeam)
        .doc(postId);
      tx.set(draftRef, {
        createdAt: FieldValue.serverTimestamp(),
        postType,
        parentIds,
      });

      return { id: postId };
    });

    /* ------------------ After tx: copy files, then update doc ----------------- */
    if (validatedAttachments.length > 0) {
      const moved: { finalPath: string }[] = [];

      try {
        for (const v of validatedAttachments) {
          const temp = incoming.find(
            (a) => sanitiseName(a.name) === sanitiseName(v.name),
          );
          assert(temp, "Validated attachment not found in input.");

          const src = bucket.file(String(temp.storagePath));
          const dest = bucket.file(v.path);

          // Copy with metadata, then delete source (move with metadata)
          await src.copy(
            dest,
            v.contentType
              ? { metadata: { contentType: v.contentType } }
              : undefined,
          );
          await src.delete();

          moved.push({ finalPath: v.path });
        }

        // Single update adding attachments (public field is fine)
        await docRef.update({ attachments: validatedAttachments });
      } catch (e) {
        // Best-effort cleanup of already-copied files
        await Promise.allSettled(
          moved.map(({ finalPath }) => bucket.file(finalPath).delete()),
        );
        throw e;
      }
    }

    return result; // { id }
  },
);
