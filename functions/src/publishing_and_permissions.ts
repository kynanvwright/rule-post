// import * as admin from "firebase-admin";
import { getFirestore, FieldValue, Timestamp } from "firebase-admin/firestore";
import { onSchedule } from "firebase-functions/v2/scheduler";
import { DateTime } from "luxon";

import { ROME_TZ } from "./config";
import { isWorkingDay } from "./working_day";

const db = getFirestore();

type TargetTime = {
  hour: number;
  minute: number;
  second?: number;
  millisecond?: number;
};

/**
 * Returns a JS Date for the target time in Rome,
 * N working days ahead of "nowRome".
 * - Counts future working days exclusive of today.
 * - Target time defaults to 19:55:00.000 if omitted.
 *
 * @param {DateTime} nowRome - Current DateTime in the Rome timezone.
 * @param {number} workDaysAhead - Working days to count forward (excl. today).
 * @param {TargetTime} [targetTime] - Optional time overrides.
 * @return {Date} JS Date at the computed target time.
 */
function computeStageEnds(
  nowRome: DateTime,
  workDaysAhead: number,
  targetTime?: TargetTime,
): Date {
  let d = nowRome;
  let added = 0;

  while (added < workDaysAhead) {
    d = d.plus({ days: 1 });
    if (isWorkingDay(d)) {
      added += 1;
    }
  }

  const tt = {
    hour: 19,
    minute: 55,
    second: 0,
    millisecond: 0,
    ...(targetTime ?? {}),
  };

  const atTarget = d.set({
    hour: tt.hour,
    minute: tt.minute,
    second: tt.second ?? 0,
    millisecond: tt.millisecond ?? 0,
  });

  return atTarget.toJSDate();
}

/**
 * Publishes all enquiries where isPublished == false.
 * Runs at 00:00 and 12:00 Europe/Rome on working days.
 * - Sets isPublished = true
 * - Sets publishedAt = server time
 * - Sets stageEnds = target time (default 19:55) in 3 working days
 */
export const enquiryPublisher = onSchedule(
  { region: "europe-west6", schedule: "0 0,12 * * *", timeZone: ROME_TZ },
  async (): Promise<void> => {
    const nowRome = DateTime.now().setZone(ROME_TZ);

    if (!isWorkingDay(nowRome)) {
      console.log(
        `[enquiryPublisher] ${nowRome.toISO()} not a working day; skipping.`,
      );
      return;
    }

    const stageEndsDate = computeStageEnds(nowRome, 3, {
      hour: 19,
      minute: 55,
      second: 0,
    });

    const publishedAt = FieldValue.serverTimestamp();

    const q = db.collection("enquiries").where("isPublished", "==", false);
    const snap = await q.get();

    if (snap.empty) {
      console.log("[enquiryPublisher] No pending enquiries.");
      return;
    }

    const writer = db.bulkWriter();
    let updated = 0;

    snap.docs.forEach((doc) => {
      writer.update(doc.ref, {
        isPublished: true,
        publishedAt,
        stageEnds: Timestamp.fromDate(stageEndsDate),
      });
      updated += 1;
    });

    await writer.close();

    console.log(
      `[enquiryPublisher] Updated ${updated} enquiries. stageEnds=` +
        stageEndsDate.toISOString(),
    );
  },
);

export const teamResponsePublisher = onSchedule(
  { region: "europe-west6", schedule: "0 20 * * *", timeZone: ROME_TZ },
  async (): Promise<void> => {
    const nowRome = DateTime.now().setZone(ROME_TZ);

    if (!isWorkingDay(nowRome)) {
      console.log(
        `[teamResponsePublisher] ${nowRome.toISO()} not a working day; ` +
          "skipping.",
      );
      return;
    }

    const nowTs = Timestamp.now();
    const q = db
      .collection("enquiries")
      .where("isPublished", "==", true)
      .where("isOpen", "==", true)
      .where("teamsCanRespond", "==", true)
      .where("stageEnds", "<", nowTs);

    const enquiriesSnap = await q.get();

    if (enquiriesSnap.empty) {
      console.log("[teamResponsePublisher] No qualifying enquiries.");
      return;
    }

    const writer = db.bulkWriter();
    let totalResponsesPublished = 0;
    let processedEnquiries = 0;

    for (const enquiryDoc of enquiriesSnap.docs) {
      const enquiryRef = enquiryDoc.ref;

      let unpublishedSnap: FirebaseFirestore.QuerySnapshot;

      try {
        unpublishedSnap = await enquiryRef
          .collection("responses")
          .where("isPublished", "==", false)
          .orderBy("createdAt", "asc")
          .get();
      } catch {
        unpublishedSnap = await enquiryRef
          .collection("responses")
          .where("isPublished", "==", false)
          .get();
      }

      if (unpublishedSnap.empty) {
        const newStageEnds = computeStageEnds(nowRome, 4, {
          hour: 11,
          minute: 55,
        });

        writer.update(enquiryRef, {
          teamsCanRespond: false,
          teamsCanComment: true,
          stageEnds: Timestamp.fromDate(newStageEnds),
        });

        processedEnquiries += 1;
        continue;
      }

      const docs = unpublishedSnap.docs;

      for (let i = 0; i < docs.length; i += 1) {
        writer.update(docs[i].ref, {
          isPublished: true,
          responseNumber: i + 1,
        });
        totalResponsesPublished += 1;
      }

      const newStageEnds = computeStageEnds(nowRome, 4, {
        hour: 11,
        minute: 55,
      });

      writer.update(enquiryRef, {
        teamsCanRespond: false,
        teamsCanComment: true,
        stageEnds: Timestamp.fromDate(newStageEnds),
      });

      processedEnquiries += 1;
    }

    await writer.close();

    console.log(
      `[teamResponsePublisher] Processed ${processedEnquiries} enquiries; ` +
        `published ${totalResponsesPublished} responses.`,
    );
  },
);

export const commentPublisher = onSchedule(
  { region: "europe-west6", schedule: "0 0,12 * * *", timeZone: ROME_TZ },
  async (): Promise<void> => {
    const nowRome = DateTime.now().setZone(ROME_TZ);

    if (!isWorkingDay(nowRome)) {
      console.log(
        `[commentPublisher] ${nowRome.toISO()} not a working day; skipping.`,
      );
      return;
    }

    const enquiriesSnap = await db
      .collection("enquiries")
      .where("isOpen", "==", true)
      .where("isPublished", "==", true)
      .where("teamsCanComment", "==", true)
      .get();

    if (enquiriesSnap.empty) {
      console.log("[commentPublisher] No qualifying enquiries.");
      return;
    }

    const writer = db.bulkWriter();
    let processedEnquiries = 0;
    let totalCommentsPublished = 0;

    for (const enquiryDoc of enquiriesSnap.docs) {
      const enquiryRef = enquiryDoc.ref;
      const enquiry = enquiryDoc.data() || {};
      const roundNumber = enquiry.roundNumber as number | undefined;

      if (typeof roundNumber !== "number") {
        console.log(
          `[commentPublisher] Enquiry ${enquiryRef.id} missing ` +
            "roundNumber; skipping comments publish for this enquiry.",
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

        if (unpublishedCommentsSnap.empty) {
          continue;
        }

        unpublishedCommentsSnap.docs.forEach((c) => {
          writer.update(c.ref, { isPublished: true });
          totalCommentsPublished += 1;
        });
      }

      const stageEnds = enquiry.stageEnds as
        | FirebaseFirestore.Timestamp
        | undefined;

      const nowTs = Timestamp.now();

      if (stageEnds && stageEnds.toMillis() < nowTs.toMillis()) {
        const newStageEndsDate = computeStageEnds(nowRome, 0, {
          hour: 23,
          minute: 55,
          second: 0,
        });

        writer.update(enquiryRef, {
          teamsCanComment: false,
          stageEnds: Timestamp.fromDate(newStageEndsDate),
        });
      }

      processedEnquiries += 1;
    }

    await writer.close();

    console.log(
      `[commentPublisher] Processed ${processedEnquiries} enquiries; ` +
        `published ${totalCommentsPublished} comments.`,
    );
  },
);

export const committeeResponsePublisher = onSchedule(
  { region: "europe-west6", schedule: "0 0 * * *", timeZone: ROME_TZ },
  async (): Promise<void> => {
    const nowRome = DateTime.now().setZone(ROME_TZ);

    if (!isWorkingDay(nowRome)) {
      console.log(
        `[committeeResponsePublisher] ${nowRome.toISO()} not a working day; ` +
          "skipping.",
      );
      return;
    }

    const nowTs = Timestamp.now();

    const enquiriesSnap = await db
      .collection("enquiries")
      .where("isOpen", "==", true)
      .where("isPublished", "==", true)
      .where("teamsCanRespond", "==", false)
      .where("teamsCanComment", "==", false)
      .where("stageEnds", "<", nowTs)
      .get();

    if (enquiriesSnap.empty) {
      console.log("[committeeResponsePublisher] No qualifying enquiries.");
      return;
    }

    let processed = 0;
    let published = 0;

    for (const enquiryDoc of enquiriesSnap.docs) {
      const enquiryRef = enquiryDoc.ref;

      try {
        await db.runTransaction(async (tx) => {
          const freshEnquirySnap = await tx.get(enquiryRef);

          if (!freshEnquirySnap.exists) {
            return;
          }

          const e = freshEnquirySnap.data() || {};
          const roundNumber = e.roundNumber as number | undefined;

          if (typeof roundNumber !== "number") {
            return;
          }

          const stillOpen =
            e.isOpen === true &&
            e.isPublished === true &&
            e.teamsCanRespond === false &&
            e.teamsCanComment === false &&
            (e.stageEnds instanceof Timestamp
              ? e.stageEnds.toMillis() < Date.now()
              : false);

          if (!stillOpen) {
            return;
          }

          const respCol = enquiryRef.collection("responses");

          const committeeSnap = await respCol
            .where("roundNumber", "==", roundNumber)
            .where("fromRC", "==", true)
            .where("isPublished", "==", false)
            .get();

          if (committeeSnap.size !== 1) {
            return;
          }

          const committeeDoc = committeeSnap.docs[0];

          tx.update(committeeDoc.ref, {
            isPublished: true,
            roundNumber: roundNumber + 1,
            responseNumber: 0,
          });

          const nextStageEnds = computeStageEnds(nowRome, 3, {
            hour: 19,
            minute: 55,
          });

          tx.update(enquiryRef, {
            roundNumber: FieldValue.increment(1),
            teamsCanRespond: true,
            stageEnds: Timestamp.fromDate(nextStageEnds),
          });

          published += 1;
        });
      } catch (err) {
        console.error(
          "[committeeResponsePublisher] Transaction failed for " +
            `enquiry ${enquiryRef.id}:`,
          err,
        );
      }

      processed += 1;
    }

    console.log(
      `[committeeResponsePublisher] Processed ${processed} enquiries; ` +
        `published ${published} committee responses.`,
    );
  },
);
