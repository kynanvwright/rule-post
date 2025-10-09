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
export { setEmailNotificationsOn } from "./toggle_notifications";
export { createUserWithProfile } from "./create_user";
export { deleteUser } from "./delete_user";
export { listTeamUsers } from "./list_team_users";
export { closeEnquiry } from "./close_enquiry";
export { committeeResponseInstantPublisher } from "./rc_response_instant_publish";
export { teamResponseInstantPublisher } from "./team_response_instant_publish";
export {
  onEnquiryIsPublishedUpdated,
  onResponseIsPublishedUpdated,
  onCommentIsPublishedUpdated,
  sendPublishDigest,
} from "./send_email_on_publish";
export { findDrafts, hasDrafts } from "./find_my_drafts";
