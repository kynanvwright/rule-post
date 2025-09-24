// workingDays.ts
import { DateTime } from "luxon";

import { ROME_TZ } from "./config";

type HolidayRange = { start: string; end: string };

// Fixed holiday ranges defined in the Class Rule (AC38)
const holidays: readonly HolidayRange[] = [
  { start: "2025-12-25", end: "2026-01-03" },
  { start: "2026-04-03", end: "2026-04-07" },
  { start: "2026-12-25", end: "2027-01-03" },
  { start: "2027-03-26", end: "2027-03-30" },
];

// Update as needed
const RACE_DATE: DateTime = DateTime.fromISO("2027-07-01", { zone: ROME_TZ });

/**
 * Returns true if the given Luxon DateTime is a working day (Europe/Rome).
 * Working days exclude:
 * - Sundays
 * - Saturdays prior to 3 months before the AC Match
 * - Dates falling within defined holiday ranges (inclusive)
 * @param {DateTime} dt - A Luxon DateTime object
 * @return {boolean} If that datetime is on a working day
 */
export const isWorkingDay = (dt: DateTime): boolean => {
  const local = dt.setZone(ROME_TZ);
  if (!local.isValid) return false;

  // Compare by calendar day in Rome to avoid time-of-day edge cases
  const day = local.startOf("day");

  // 1 = Mon ... 7 = Sun
  const weekday = day.weekday;
  if (weekday === 7) return false; // Sunday

  // Saturday cutoff: Saturdays are non-working ONLY before this date
  const saturdayCutoff = RACE_DATE.setZone(ROME_TZ)
    .startOf("day")
    .minus({ months: 3 });

  if (weekday === 6 && day < saturdayCutoff) return false; // Saturday before cutoff

  // Holiday check (inclusive of start and end dates)
  // Assumes holidays: Array<{ start: string; end: string }>, ISO "YYYY-MM-DD"
  const inHoliday = holidays.some(({ start, end }) => {
    const startDt = DateTime.fromISO(start, { zone: ROME_TZ }).startOf("day");
    const endDt = DateTime.fromISO(end, { zone: ROME_TZ }).endOf("day");
    return day >= startDt && day <= endDt;
  });

  if (inHoliday) return false;

  return true;
};
