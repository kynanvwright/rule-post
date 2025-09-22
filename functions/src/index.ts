import {setGlobalOptions} from "firebase-functions/v2";
import {beforeUserCreated} from "firebase-functions/v2/identity";
import {HttpsError} from "firebase-functions/v2/https";
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

/** Block all self-registration */
export const blockAllSelfRegistration = beforeUserCreated(() => {
  throw new HttpsError(
    "permission-denied",
    "Self-registration is disabled.",
  );
});


import {createPost} from "./posts";
// Re-export the Cloud Functions
export {createPost};

import {
  enquiryPublisher,
  teamResponsePublisher,
  commentPublisher,
  committeeResponsePublisher,
} from "./publishing_and_permissions";

exports.enquiryPublisher=enquiryPublisher;
exports.teamResponsePublisher=teamResponsePublisher;
exports.commentPublisher=commentPublisher;
exports.committeeResponsePublisher=committeeResponsePublisher;
