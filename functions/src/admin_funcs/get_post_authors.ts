// ──────────────────────────────────────────────────────────────────────────────
// File: src/admin_funcs/get_post_authors.ts
// Purpose: Reveal author team identities for posts within an enquiry (admin/RC only)
// Security: Backend-mediated; logs all calls for audit trail; throttled to prevent enumeration
// ──────────────────────────────────────────────────────────────────────────────
import { getFirestore } from "firebase-admin/firestore";
import { logger } from "firebase-functions";
import { onCall, HttpsError } from "firebase-functions/v2/https";

import { REGION, TIMEOUT_SECONDS } from "../common/config";
import { throttleAdminFunction } from "../common/rate_limit";

const db = getFirestore();

type AuthorMapResult = {
  ok: boolean;
  authors?: Record<string, string>; // postId -> authorTeam
  error?: string;
};

/**
 * Admin/RC only: retrieve author team identities for all posts (responses + comments)
 * within an enquiry. Returns a map of {postId: authorTeam}.
 *
 * Security model:
 * - Caller must be admin (role="admin") or RC (team="RC")
 * - Fetches protected /meta/data subcollections (backend has full access)
 * - Logs call for audit trail: {adminUid, enquiryId, timestamp, count}
 * - Frontend should render authors only to admin/RC users
 *
 * Prevents bulk scraping via:
 * - IsRPC/admin-only check
 * - Audit logging every call
 * - Optional rate limiting (not implemented yet; can add middleware later)
 */
export const getPostAuthorsForEnquiry = onCall<{
  enquiryId: string;
}>(
  {
    region: REGION,
    cors: true,
    timeoutSeconds: TIMEOUT_SECONDS,
    enforceAppCheck: true,
  },
  async (req): Promise<AuthorMapResult> => {
    // ──────────────────────────────────────────────────────────────────────
    // 1) AuthZ: Must be admin or RC
    // ──────────────────────────────────────────────────────────────────────
    const callerUid = req.auth?.uid;
    if (!callerUid) {
      throw new HttpsError("unauthenticated", "You must be signed in.");
    }

    const isAdmin = req.auth?.token.role === "admin";
    const isRC = req.auth?.token.team === "RC";
    if (!isAdmin && !isRC) {
      throw new HttpsError(
        "permission-denied",
        "Only admins and Rules Committee can view post authors.",
      );
    }

    // ──────────────────────────────────────────────────────────────────────
    // 1.5) Throttle: 1 call per 5 seconds per user (prevent enumeration attacks)
    // ──────────────────────────────────────────────────────────────────────
    const { abuseAlert } = await throttleAdminFunction(
      callerUid,
      "getPostAuthorsForEnquiry",
    );

    // ──────────────────────────────────────────────────────────────────────
    // 2) Input validation
    // ──────────────────────────────────────────────────────────────────────
    const enquiryId = (req.data as Record<string, unknown>)?.enquiryId;
    if (typeof enquiryId !== "string") {
      throw new HttpsError("invalid-argument", "enquiryId must be a string.");
    }

    const trimmedId = enquiryId.trim();
    if (!trimmedId) {
      throw new HttpsError("invalid-argument", "enquiryId is required.");
    }

    // Prevent path traversal
    if (trimmedId.includes("/")) {
      throw new HttpsError(
        "invalid-argument",
        "enquiryId must be a single segment (no slashes).",
      );
    }

    // ──────────────────────────────────────────────────────────────────────
    // 3) Verify enquiry exists
    // ──────────────────────────────────────────────────────────────────────
    const enquiryRef = db.collection("enquiries").doc(trimmedId);
    const enquirySnap = await enquiryRef.get();
    if (!enquirySnap.exists) {
      throw new HttpsError("not-found", `Enquiry ${trimmedId} does not exist.`);
    }

    // ──────────────────────────────────────────────────────────────────────
    // 4) Build author map: fetch all responses + comments in enquiry
    // ──────────────────────────────────────────────────────────────────────
    const authorMap: Record<string, string> = {};
    let totalPostsProcessed = 0;

    try {
      // Fetch enquiry meta (to get enquiry author if stored)
      let enquiryAuthorTeam: string | undefined;
      try {
        const enquiryMetaRef = enquiryRef.collection("meta").doc("data");
        const enquiryMetaSnap = await enquiryMetaRef.get();
        if (enquiryMetaSnap.exists) {
          enquiryAuthorTeam = enquiryMetaSnap.get("authorTeam") as
            | string
            | undefined;
          if (enquiryAuthorTeam) {
            authorMap[trimmedId] = enquiryAuthorTeam;
            logger.debug("[getPostAuthorsForEnquiry] enquiry author found", {
              enquiryId: trimmedId,
              authorTeam: enquiryAuthorTeam,
            });
          }
        }
      } catch (metaErr) {
        logger.warn("[getPostAuthorsForEnquiry] failed to fetch enquiry meta", {
          enquiryId: trimmedId,
          error: String(metaErr),
        });
        // Don't fail entirely; continue to responses
      }

      // Fetch all responses
      let responsesSnap;
      try {
        responsesSnap = await enquiryRef.collection("responses").get();
      } catch (respErr) {
        logger.error("[getPostAuthorsForEnquiry] failed to list responses", {
          enquiryId: trimmedId,
          error: String(respErr),
        });
        throw new HttpsError(
          "internal",
          "Failed to list responses for enquiry.",
        );
      }

      logger.debug("[getPostAuthorsForEnquiry] responses found", {
        count: responsesSnap.size,
        enquiryId: trimmedId,
      });

      for (const responseDoc of responsesSnap.docs) {
        const responseId = responseDoc.id;

        try {
          const metaSnap = await responseDoc.ref
            .collection("meta")
            .doc("data")
            .get();
          if (metaSnap.exists) {
            const authorTeam = metaSnap.get("authorTeam") as string | undefined;
            if (authorTeam) {
              authorMap[responseId] = authorTeam;
              logger.debug("[getPostAuthorsForEnquiry] response author found", {
                enquiryId: trimmedId,
                responseId,
                authorTeam,
              });
            }
          }
        } catch (respMetaErr) {
          logger.warn(
            "[getPostAuthorsForEnquiry] failed to fetch response meta",
            {
              enquiryId: trimmedId,
              responseId,
              error: String(respMetaErr),
            },
          );
          // Continue to next response
        }
        totalPostsProcessed++;

        // Fetch comments for this response
        let commentsSnap;
        try {
          commentsSnap = await responseDoc.ref.collection("comments").get();
        } catch (commentsErr) {
          logger.warn("[getPostAuthorsForEnquiry] failed to list comments", {
            enquiryId: trimmedId,
            responseId,
            error: String(commentsErr),
          });
          continue; // Skip comments for this response
        }

        for (const commentDoc of commentsSnap.docs) {
          const commentId = commentDoc.id;

          try {
            const commentMetaSnap = await commentDoc.ref
              .collection("meta")
              .doc("data")
              .get();
            if (commentMetaSnap.exists) {
              const authorTeam = commentMetaSnap.get("authorTeam") as
                | string
                | undefined;
              if (authorTeam) {
                // Use composite key for clarity: "response_{id}_comment_{id}"
                authorMap[`${responseId}_${commentId}`] = authorTeam;
                logger.debug(
                  "[getPostAuthorsForEnquiry] comment author found",
                  {
                    enquiryId: trimmedId,
                    responseId,
                    commentId,
                    authorTeam,
                  },
                );
              }
            }
          } catch (commentMetaErr) {
            logger.warn(
              "[getPostAuthorsForEnquiry] failed to fetch comment meta",
              {
                enquiryId: trimmedId,
                responseId,
                commentId,
                error: String(commentMetaErr),
              },
            );
            // Continue to next comment
          }
          totalPostsProcessed++;
        }
      }
    } catch (error) {
      logger.error("[getPostAuthorsForEnquiry] error fetching author data", {
        enquiryId: trimmedId,
        callerUid,
        error: String(error),
        // Try to get stack trace if available
        stack: (error as Error)?.stack,
      });
      throw new HttpsError(
        "internal",
        "Failed to retrieve author information.",
      );
    }

    // ──────────────────────────────────────────────────────────────────────
    // 5) Audit log (all calls logged for admin/RC)
    // ──────────────────────────────────────────────────────────────────────
    logger.info("[getPostAuthorsForEnquiry] reveal called", {
      callerUid,
      isAdmin,
      isRC,
      enquiryId: trimmedId,
      authorCount: Object.keys(authorMap).length,
      totalPostsProcessed,
      abuseAlert,
      timestamp: new Date().toISOString(),
    });

    // ──────────────────────────────────────────────────────────────────────
    // 6) Return
    // ──────────────────────────────────────────────────────────────────────
    return {
      ok: true,
      authors: authorMap,
    };
  },
);
