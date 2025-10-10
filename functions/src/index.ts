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
export { blockAllSelfRegistration } from "./users/new_users";
export { createPost } from "./posts/create_post";
export { enquiryPublisher } from "./scheduled_funcs/enquiry_publisher";
export { teamResponsePublisher } from "./scheduled_funcs/team_response_publisher";
export { committeeResponsePublisher } from "./scheduled_funcs/committee_response_publisher";
export { commentPublisher } from "./scheduled_funcs/comment_publisher";

export { syncCustomClaims } from "./users/claims_sync";
export { setEmailNotificationsOn } from "./notifications/toggle_notifications";
export { createUserWithProfile } from "./users/create_user";
export { deleteUser } from "./users/delete_user";
export { listTeamUsers } from "./utils/list_team_users";
export { closeEnquiry } from "./admin_funcs/close_enquiry";
export { responseInstantPublisher } from "./admin_funcs/response_instant_publisher";
export {
  onEnquiryIsPublishedUpdated,
  onResponseIsPublishedUpdated,
  onCommentIsPublishedUpdated,
  sendPublishDigest,
} from "./notifications/send_email_on_publish";
export { findDrafts, hasDrafts } from "./utils/find_drafts";
