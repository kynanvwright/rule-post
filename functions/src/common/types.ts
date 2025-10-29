// ────────────────────────────────────────────────────────────────────────────
// File: src/common/types.ts
// Purpose: Shared TS types
// ────────────────────────────────────────────────────────────────────────────
import { Timestamp } from "firebase-admin/firestore";

export type TempAttachmentIn = {
  name: string;
  storagePath: string;
  size?: number;
  contentType?: string;
};

export type FinalisedAttachment = {
  name: string; // final name used in GCS
  path: string; // full storage path (folder + name)
  url?: string; // will be overwritten with tokened URL on publish
  token?: string; // optional, for debugging/visibility
  size?: number;
  contentType?: string;
};

export type CreatePostData = {
  postType: "enquiry" | "response" | "comment";
  title?: string;
  postText?: string;
  attachments?: TempAttachmentIn[];
  parentIds?: string[]; // response: [enquiryId], comment: [enquiryId, responseId]
};

type EditAttachmentMap = {
  add: boolean;
  remove: boolean;
  removeList: string[];
};

export type EditPostData = CreatePostData & {
  postId: string;
  isPublished: boolean;
  editAttachments: EditAttachmentMap;
};

export type AuthorInfo = {
  uid: string;
  team: string; // validated non-empty
};

export type TxResult = {
  postId: string;
  postPath: string;
  postType: CreatePostData["postType"];
  enquiryNumber?: number; // for new enquiries
};

export type TargetTime = {
  hour: number;
  minute: number;
  second?: number;
  millisecond?: number;
};

export type idPayload = {
  enquiryID: string;
};

export type instantPublishPayload = {
  enquiryID: string;
  rcResponse: boolean;
};

export type changeStageLengthPayload = {
  enquiryID: string;
  newStageLength: number;
};

/* ─────────────────────────────── Notifications ─────────────────────────────── */

export type ISODate = Timestamp;

export interface BasePublishable {
  isPublished?: boolean;
  title?: string;
  publishedAt?: ISODate;
}

export interface EnquiryDoc extends BasePublishable {
  enquiryNumber?: string;
}
export interface ResponseDoc extends BasePublishable {
  roundNumber?: string;
  responseNumber?: string;
}
export interface CommentDoc extends BasePublishable {
  commentNumber?: string;
}

export type PublishKind = "enquiry" | "response" | "comment";

export interface PublishEventData {
  kind: PublishKind;
  enquiryId: string;
  responseId?: string;
  commentId?: string;
  enquiryTitle?: string;
  createdAt: ISODate;
  publishedAt: ISODate;
  processed: boolean;
  processedAt?: ISODate;
  enquiryNumber?: string;
  roundNumber?: string;
  responseNumber?: string;
  commentNumber?: string;
}

export interface EnquiryParams {
  enquiryId: string;
}
export interface ResponseParams extends EnquiryParams {
  responseId: string;
}
export interface CommentParams extends ResponseParams {
  commentId: string;
}

export interface UserData {
  emailNotificationsOn?: boolean;
  email?: string;
}
