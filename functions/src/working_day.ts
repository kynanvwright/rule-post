// workingDays.ts
import {DateTime} from "luxon";
import {ROME_TZ} from "./config";

type HolidayRange = {start: string; end: string};

// Fixed holiday ranges defined in the Class Rule (AC38)
const holidays: readonly HolidayRange[] = [
  {start: "2025-12-25", end: "2026-01-03"},
  {start: "2026-04-03", end: "2026-04-07"},
  {start: "2026-12-25", end: "2027-01-03"},
  {start: "2027-03-26", end: "2027-03-30"},
];

// Update as needed
const RACE_DATE: DateTime = DateTime.fromISO("2027-07-01", {zone: ROME_TZ});

/**
 * Returns true if the given Luxon DateTime is a working day.
 * Working days exclude:
 * - Sundays
 * - Saturdays prior to 3 months before the AC Match
 * - Dates falling within defined holiday ranges
 * @param {DateTime} dt - A Luxon DateTime object
 * @return {Boolean} If that datetime is on a working day
 */
export const isWorkingDay = (dt: DateTime): boolean => {
  const local = dt.setZone(ROME_TZ);
  const weekday = local.weekday; // 1 = Mon, 7 = Sun
  if (weekday === 7) return false; // Sundays excluded

  // Check if date falls within any holiday range (inclusive start and end)
  const inHoliday = holidays.some(({start, end}) => {
    const startDt = DateTime.fromISO(start, {zone: ROME_TZ});
    const endDt = DateTime.fromISO(end, {zone: ROME_TZ});
    // Inclusive on both ends
    return local >= startDt && local <= endDt;
  });

  // Saturday cutoff: 3 months before the AC Match
  const saturdayCutoff = RACE_DATE.minus({months: 3});

  // Prior to the cutoff, Saturdays are excluded
  if (weekday === 6 && local < saturdayCutoff) return false;

  return !inHoliday;
};
