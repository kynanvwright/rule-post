// ──────────────────────────────────────────────────────────────────────────────
// File: src/utils/unread_post_generator.ts
// Purpose: Create unread post records in user data collection
// ──────────────────────────────────────────────────────────────────────────────
import { getFirestore, FieldValue, BulkWriter } from "firebase-admin/firestore";
import { logger } from "firebase-functions";

import { PostType } from "../common/types";

const db = getFirestore();

/** Common unread record fields */
type BaseUnread = {
  postType: PostType;
  postAlias: string;
  createdAt: FirebaseFirestore.FieldValue;
  isUnread?: boolean;
};

/** IDs relevant to each post type */
type EnquiryFields = {
  hasUnreadChild?: boolean;
};
type ResponseFields = {
  hasUnreadChild?: boolean;
  parentId: string;
};
type CommentFields = {
  parentId: string;
  grandparentId: string;
};

type FieldBundle<T extends PostType> = T extends "enquiry"
  ? EnquiryFields
  : T extends "response"
    ? ResponseFields
    : T extends "comment"
      ? CommentFields
      : never;

/** Per-type payloads */
type UnreadEnquiry = BaseUnread & EnquiryFields;
type UnreadResponse = BaseUnread & ResponseFields;
type UnreadComment = BaseUnread & CommentFields;

type UnreadRecord = UnreadEnquiry | UnreadResponse | UnreadComment;

/** Build the record payload, branching on postType. */
function buildUnreadRecord<T extends PostType>(
  postType: T,
  postAlias: string,
  isUnread: boolean,
  postFields: FieldBundle<T>,
): UnreadRecord {
  const base: BaseUnread = {
    postType,
    postAlias,
    createdAt: FieldValue.serverTimestamp(),
  };
  const unreadPayload: Record<string, boolean> = isUnread
    ? {
        isUnread: true,
      }
    : {
        hasUnreadChild: true,
      };

  return { ...base, ...unreadPayload, ...postFields };
}

/**
 * Create unread records under every user:
 *   user_data/{uid}/unreadPosts/{docId}
 *
 * @param postType     "enquiry" | "response" | "comment"
 * @param docId        the post Id
 * @param isUnread     boolean whether the post itself is unread, or it's being marked due to a child post
 * @param postFields   extra fields which vary by post type
 * @returns number of user docs written
 */
export async function createUnreadForAllUsers<T extends PostType>(
  writer: BulkWriter,
  postType: T,
  postAlias: string,
  docId: string,
  isUnread: boolean,
  postFields: FieldBundle<T>,
  userTeam?: string,
): Promise<{ attempted: number; updated: number }> {
  let attempted = 0;
  let updated = 0;

  // Build query
  let q: FirebaseFirestore.Query = db.collection("user_data");
  if (userTeam && userTeam.trim()) {
    // Only users on this team
    q = q.where("team", "==", userTeam.trim());
  }
  // Get doc refs/ids
  const usersSnap = await q.select().get();

  const payload = buildUnreadRecord(postType, postAlias, isUnread, postFields);

  for (const userDoc of usersSnap.docs) {
    attempted++;
    const ref = userDoc.ref.collection("unreadPosts").doc(docId);
    try {
      await writer.set(ref, payload, { merge: true });
      updated++;
    } catch (e) {
      logger.warn(
        `[createUnreadForAllUsers] Unread post write failed for post: ${docId} and user: ${userDoc.id}. Error: ${e}.`,
      );
    }
  }

  return { attempted, updated };
}
