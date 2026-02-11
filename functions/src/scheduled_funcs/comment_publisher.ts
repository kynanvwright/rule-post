// ──────────────────────────────────────────────────────────────────────────────
// Purpose: Publishes comments and updates counts; 00:00 & 12:00 Rome working days
// ──────────────────────────────────────────────────────────────────────────────
import { FieldValue, getFirestore, Timestamp } from "firebase-admin/firestore";
import { logger } from "firebase-functions";
import { onSchedule } from "firebase-functions/v2/scheduler";
import { DateTime } from "luxon";

import { SCHED_REGION_ROME, ROME_TZ, TIMEOUT_SECONDS } from "../common/config";
import { computeStageEnds } from "../utils/compute_stage_ends";
import {
  readAuthorTeam,
  queueDraftDelete,
  stageUpdatePayload,
} from "../utils/publish_helpers";
import { createUnreadForAllUsers } from "../utils/unread_post_generator";
import { isWorkingDay } from "../working_day";

const db3 = getFirestore();

export const commentPublisher = onSchedule(
  {
    region: SCHED_REGION_ROME,
    schedule: "0 0,12 * * *", // if changed, requires change to calculateNextCommentPublicationTime
    timeZone: ROME_TZ,
    timeoutSeconds: TIMEOUT_SECONDS,
  },
  async (): Promise<void> => {
    const nowRome = DateTime.now().setZone(ROME_TZ);
    const publishedAt = FieldValue.serverTimestamp();

    if (!isWorkingDay(nowRome)) {
      logger.info(
        `[commentPublisher] ${nowRome.toISO()} not a working day; skipping.`,
      );
      return;
    }

    const enquiriesSnap = await db3
      .collection("enquiries")
      .where("isOpen", "==", true)
      .where("isPublished", "==", true)
      .where("teamsCanComment", "==", true)
      .get();

    if (enquiriesSnap.empty) {
      logger.info("[commentPublisher] No qualifying enquiries.");
      return;
    }

    const writer = db3.bulkWriter();
    let processedEnquiries = 0;
    let totalCommentsPublished = 0;

    for (const enquiryDoc of enquiriesSnap.docs) {
      const enquiryRef = enquiryDoc.ref;
      const roundNumber = enquiryDoc.get("roundNumber") as number | undefined;
      if (typeof roundNumber !== "number") {
        logger.warn(
          `[commentPublisher] Enquiry ${enquiryRef.id} missing roundNumber; skipping.`,
        );
        processedEnquiries += 1;
        continue;
      }

      const responsesSnap = await enquiryRef
        .collection("responses")
        .where("roundNumber", "==", roundNumber)
        .get();

      for (const respDoc of responsesSnap.docs) {
        const commentsCol = respDoc.ref.collection("comments");
        const unpublishedCommentsSnap = await commentsCol
          .where("isPublished", "==", false)
          .get();
        if (unpublishedCommentsSnap.empty) continue;

        const publishedCountSnap = await commentsCol
          .where("isPublished", "==", true)
          .count()
          .get();

        const alreadyPublished = publishedCountSnap.data().count;

        for (const [i, c] of unpublishedCommentsSnap.docs.entries()) {
          // publish comment
          const commentNumber = alreadyPublished + 1 + i;
          writer.update(c.ref, {
            isPublished: true,
            publishedAt,
            commentNumber,
          });
          totalCommentsPublished += 1;

          // delete draft
          const team = await readAuthorTeam(c.ref);
          if (!team) {
            logger.warn(
              `[commentPublisher] No team found for ${c.id}, skipping draft delete.`,
            );
          } else {
            queueDraftDelete(writer, team, c.id);
          }

          // add unreadPost entries for users
          await createUnreadForAllUsers(
            writer,
            "comment",
            `Comment #${commentNumber}`,
            c.ref.id,
            true,
            {
              parentId: respDoc.id,
              grandparentId: enquiryDoc.id,
            },
          );
        }
        // update commentCount deterministically after flush
        await writer.flush();
        const published = await commentsCol
          .where("isPublished", "==", true)
          .get();
        writer.update(respDoc.ref, { commentCount: published.size });

        // add unreadPost entries for users
        await createUnreadForAllUsers(
          writer,
          "response",
          `Response ${respDoc.data()?.roundNumber}.${respDoc.data()?.responseNumber}`,
          respDoc.id,
          false,
          {
            parentId: enquiryDoc.id,
          },
        );
      }

      const stageEnds = enquiryDoc.get("stageEnds") as
        | FirebaseFirestore.Timestamp
        | undefined;
      const nowTs = Timestamp.now();
      if (stageEnds && stageEnds.toMillis() < nowTs.toMillis()) {
        const newStageEndsDate = computeStageEnds(1, { hour: 23, minute: 59 });
        writer.update(enquiryRef, {
          teamsCanRespond: false,
          teamsCanComment: false,
          ...stageUpdatePayload(newStageEndsDate),
        });
      }

      // add unreadPost entries for users
      await createUnreadForAllUsers(
        writer,
        "enquiry",
        `RE #${enquiryDoc.data().enquiryNumber} - ${enquiryDoc.data().title}`,
        enquiryDoc.id,
        false,
        {},
      );

      processedEnquiries += 1;
    }

    await writer.close();
    logger.info(
      `[commentPublisher] Processed ${processedEnquiries} enquiries; published ${totalCommentsPublished} comments.`,
    );

    // Calculate and save the next scheduled publication time
    const nextPublicationTime = calculateNextCommentPublicationTime(nowRome);
    await db3.collection("app_data").doc("date_times").update({
      nextCommentPublicationTime: nextPublicationTime.toJSDate(),
    });
  },
);

/**
 * Calculates the next scheduled comment publication time in Rome timezone.
 * Comments publish at 00:00 and 12:00 Rome time.
 * 
 * @param nowRome Current time in Rome timezone (ROME_TZ)
 * @returns DateTime in Rome timezone for the next publication slot
 */
function calculateNextCommentPublicationTime(
  nowRome: DateTime,
): DateTime {
  // If we're before noon, next publication is at noon today
  if (nowRome.hour < 12) {
    return nowRome.set({ hour: 12, minute: 0, second: 0, millisecond: 0 });
  }

  // Otherwise, next publication is at midnight tomorrow
  return nowRome
    .plus({ days: 1 })
    .set({ hour: 0, minute: 0, second: 0, millisecond: 0 });
}
