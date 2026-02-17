import { getFirestore } from "firebase-admin/firestore";
import { logger } from "firebase-functions";
import { DateTime } from "luxon";

import { ROME_TZ } from "../common/config";
import { isWorkingDay } from "../working_day";

const db = getFirestore();

/**
 * Find the next publish slot (00:00 or 12:00 Rome time) that is strictly after now
 * and where the calendar day is a working day.
 */
function calculateNextCommentPublicationTime(nowRome: DateTime): DateTime {
  // Start at today's midnight in Rome and scan forward for the first qualifying slot
  let day = nowRome.startOf("day");

  // Search up to 30 days ahead as a safety cap
  for (let i = 0; i < 30; i += 1) {
    if (isWorkingDay(day)) {
      const slots = [
        day.set({ hour: 0, minute: 0, second: 0, millisecond: 0 }),
        day.set({ hour: 12, minute: 0, second: 0, millisecond: 0 }),
      ];

      for (const slot of slots) {
        if (slot > nowRome) return slot;
      }
    }
    day = day.plus({ days: 1 }).startOf("day");
  }

  // Fallback: next working day's 12:00
  let next = nowRome.plus({ days: 1 }).startOf("day");
  while (!isWorkingDay(next)) next = next.plus({ days: 1 }).startOf("day");
  return next.set({ hour: 12, minute: 0, second: 0, millisecond: 0 });
}

/** Helper function extracted for use by orchestrator */
export async function doCommentPublicationScheduleRefresh(): Promise<void> {
  const nowRome = DateTime.now().setZone(ROME_TZ);
  const next = calculateNextCommentPublicationTime(nowRome);

  await db
    .collection("app_data")
    .doc("date_times")
    .set({ nextCommentPublicationTime: next.toJSDate() }, { merge: true });

  logger.info(
    `[doCommentPublicationScheduleRefresh] nowRome=${nowRome.toISO()} next=${next.toISO()}`,
  );
}

// ✅ Note: commentPublicationScheduleRefresher is no longer exported directly.
// It is called by the orchestrator (orchestrate0000).
// Legacy export commented out:
/*
export const commentPublicationScheduleRefresher = onSchedule(
  {
    region: SCHED_REGION_ROME,
    schedule: "1 0,12 * * *",
    timeZone: ROME_TZ,
    timeoutSeconds: TIMEOUT_SECONDS,
  },
  async (): Promise<void> => {
    await doCommentPublicationScheduleRefresh();
  },
);
*/
