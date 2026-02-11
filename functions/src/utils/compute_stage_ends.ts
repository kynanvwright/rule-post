// ──────────────────────────────────────────────────────────────────────────────
// File: src/schedule/compute_stage_ends.ts
// Purpose: Compute next stage boundary in Rome time across working days
// ──────────────────────────────────────────────────────────────────────────────
import { Timestamp } from "firebase-admin/firestore";
import { DateTime } from "luxon";

import { ROME_TZ } from "../common/config";
import { isWorkingDay } from "../working_day";

import type { TargetTime } from "../common/types";

/**
 * Returns a JS Date for the target time in Rome, N working days ahead of "now" (inclusive of today).
 * - Counts working days inclusive of today.
 * - If today's target time has already passed, rolls to the next working day.
 * - Target time defaults to 19:59:00.000 if omitted.
 */
export function computeStageEnds(
  workDaysAhead: number,
  targetTime?: TargetTime,
): Date {
  if (!Number.isFinite(workDaysAhead) || workDaysAhead <= 0) {
    throw new Error("workDaysAhead must be a positive number");
  }

  const now = Timestamp.now().toDate();
  const nowRome = DateTime.fromJSDate(now).setZone(ROME_TZ);

  const tt = {
    hour: 19,
    minute: 59,
    second: 0,
    millisecond: 0,
    ...(targetTime ?? {}),
  } as const;

  // Start counting from today's midnight (Rome), inclusive
  let d = nowRome.startOf("day");
  let remaining = workDaysAhead;

  while (remaining > 0) {
    if (isWorkingDay(d)) {
      if (remaining === 1) {
        const atTargetRome = d.set(tt);
        if (atTargetRome <= nowRome) {
          // roll forward to next working day at same target time
          let next = d;
          do {
            next = next.plus({ days: 1 }).startOf("day");
          } while (!isWorkingDay(next));
          return next.set(tt).toUTC().toJSDate();
        }
        return atTargetRome.toUTC().toJSDate();
      }
      remaining -= 1;
    }
    d = d.plus({ days: 1 }).startOf("day");
  }
  throw new Error("No valid working day found");
}
