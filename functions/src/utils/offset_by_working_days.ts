// ──────────────────────────────────────────────────────────────────────────────
// File: src/schedule/shift_working_days.ts
// Purpose: Move forward or backward a number of working days from a timestamp
// ──────────────────────────────────────────────────────────────────────────────
import { Timestamp } from "firebase-admin/firestore";
import { DateTime } from "luxon";

import { ROME_TZ } from "../common/config";
import { isWorkingDay } from "../working_day";

/**
 * Returns a JS Date that is `nDays` working days away from the given timestamp.
 * - Keeps the same time of day.
 * - Positive nDays → forward, negative → backward.
 */
export function offsetByWorkingDays(ts: Timestamp, nDays: number): Date {
  if (!Number.isFinite(nDays) || nDays === 0) {
    return ts.toDate();
  }

  const forward = nDays > 0;
  let remaining = Math.abs(nDays);

  // Convert to Luxon in Rome time
  let d = DateTime.fromJSDate(ts.toDate()).setZone(ROME_TZ);

  while (remaining > 0) {
    d = d.plus({ days: forward ? 1 : -1 });
    if (isWorkingDay(d)) remaining -= 1;
  }

  // Return same local time but in UTC
  return d.toUTC().toJSDate();
}
