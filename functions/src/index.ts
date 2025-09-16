import {setGlobalOptions, logger} from "firebase-functions";
import {beforeUserCreated} from "firebase-functions/v2/identity";
import {onCall, HttpsError}
  from "firebase-functions/v2/https";
import * as admin from "firebase-admin";

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

/**
 * Block all self-registration.
 */
export const blockAllSelfRegistration = beforeUserCreated(() => {
  throw new HttpsError(
    "permission-denied",
    "Self-registration is disabled.",
  );
});

/** Payload for createEnquiry callable. */

export const createEnquiry = onCall(async (req) => {
  if (!req.auth?.uid) {
    throw new HttpsError(
      "unauthenticated",
      "Sign in required.");
  }
  const authorUid = req.auth.uid;

  const titleText = String(req.data?.titleText ?? "").trim();
  const enquiryText = String(req.data?.enquiryText ?? "").trim();
  if (!titleText || !enquiryText) {
    throw new HttpsError(
      "invalid-argument",
      "titleText and enquiryText are required.");
  }

  const db = admin.firestore();
  const now = admin.firestore.FieldValue.serverTimestamp();

  const result = await db.runTransaction(async (tx) => {
    const docRef = db.collection("enquiries").doc();
    const metaRef = db.collection("enquiries_meta").doc(docRef.id);

    tx.set(docRef, {
      titleText: titleText, 
      enquiryText: enquiryText,
      createdAt: now});
    tx.set(metaRef, {
      authorUid: authorUid,
      authorEmail: null,
      createdAt: now,
      createdByProvider: null,
    });
    return {id: docRef.id};
  });
  return result;
});

export const ping = onCall((req) => {
  logger.info("ping invoked", {
    hasAuth: !!req.auth,
    region: process.env.FUNCTION_REGION,
  });
  return {ok: true, ts: Date.now()};
});

