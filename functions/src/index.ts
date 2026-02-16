// ──────────────────────────────────────────────────────────────────────────────
// File: src/index.ts
// ──────────────────────────────────────────────────────────────────────────────
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
/** ─────────────────────────────── Users ─────────────────────────────── */
export { blockAllSelfRegistration } from "./users/new_users";
export { createUserWithProfile } from "./users/create_user";
export { deleteUser } from "./users/delete_user";
export { syncCustomClaims } from "./users/claims_sync";

/** ─────────────────────────────── Posts ─────────────────────────────── */
export { createPost } from "./posts/create_post";
export { editPost } from "./posts/edit_post";
export { deletePost } from "./posts/delete_post";
export {
  onEnquiryDeleted,
  onResponseDeleted,
  onCommentDeleted,
} from "./posts/deleted_post_actions";

/** ──────────────────────────── Notifications ────────────────────────── */
export {
  onEnquiryIsPublishedUpdated,
  onResponseIsPublishedUpdated,
  onCommentIsPublishedUpdated,
  sendPublishDigest,
} from "./notifications/send_publish_digest";
export { toggleEmailNotifications } from "./notifications/toggle_notifications";

/** ───────────────────────────── Scheduled ───────────────────────────── */
export { enquiryPublisher } from "./scheduled_funcs/enquiry_publisher";
export { teamResponsePublisher } from "./scheduled_funcs/team_response_publisher";
export { committeeResponsePublisher } from "./scheduled_funcs/committee_response_publisher";
export { commentPublisher } from "./scheduled_funcs/comment_publisher";
export { commentPublicationScheduleRefresher } from "./scheduled_funcs/comment_publication_schedule";

/** ─────────────────────────────── Admin ─────────────────────────────── */
export { changeStageLength } from "./admin_funcs/change_stage_length";
export { closeEnquiry } from "./admin_funcs/close_enquiry";
export { getPostAuthorsForEnquiry } from "./admin_funcs/get_post_authors";
// export { markPostUnread } from "./admin_funcs/mark_post_unread";
export { responseInstantPublisher } from "./admin_funcs/response_instant_publisher";

/** ─────────────────────────────── Utils ─────────────────────────────── */
