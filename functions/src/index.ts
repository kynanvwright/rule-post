// src/index.ts
import { getApps, initializeApp } from "firebase-admin/app";
import { setGlobalOptions } from "firebase-functions/v2";

/** Global options for all functions. */
setGlobalOptions({
  region: "europe-west8",
  maxInstances: 10,
});

if (!getApps().length) {
  initializeApp();
}

/** App functions (re-exports) */
export { blockAllSelfRegistration } from "./new_users";
export { createPost } from "./posts";
export {
  enquiryPublisher,
  teamResponsePublisher,
  commentPublisher,
  committeeResponsePublisher,
} from "./publishing_and_permissions";
export { syncCustomClaims } from "./claims_sync";
export { setEmailNotificationsOn } from "./toggleNotifications";
export { createFirebaseUser } from "./createUser";
