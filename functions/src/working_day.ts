// workingDays.ts
import {DateTime} from 'luxon';
import {ROME_TZ} from './config';

type HolidayRange = {start: string; end: string};

// Fixed holiday ranges defined in the Class Rule (AC38)
const holidays: readonly HolidayRange[] = [
  {start: '2025-12-25', end: '2026-01-03'},
  {start: '2026-04-03', end: '2026-04-07'},
  {start: '2026-12-25', end: '2027-01-03'},
  {start: '2027-03-26', end: '2027-03-30'},
];

// Update as needed
const RACE_DATE: DateTime = DateTime.fromISO('2027-07-01', {zone: ROME_TZ});

/**
 * Returns true if the given Luxon DateTime is a working day.
 * Working days exclude:
 * - Sundays
 * - Saturdays prior to 3 months before the AC Match
 * - Dates falling within defined holiday ranges
 */
export const isWorkingDay = (dt: DateTime): boolean => {
  const local = dt.setZone(ROME_TZ);
  const weekday = local.weekday; // 1 = Monday, 7 = Sunday
  if (weekday === 7) return false; // Sundays excluded

  // Check if the date falls within any holiday range (inclusive start, exclusive end)
  const inHoliday = holidays.some(({start, end}) => {
    const startDt = DateTime.fromISO(start, {zone: ROME_TZ});
    const endDt = DateTime.fromISO(end, {zone: ROME_TZ});
    // Luxon DateTime implements valueOf() so relational operators compare by epoch ms
    return local >= startDt && local < endDt;
  });

  // Saturday cutoff: 3 months before the AC Match
  const saturdayCutoff = RACE_DATE.minus({months: 3});

  // Prior to the cutoff, Saturdays are excluded
  if (weekday === 6 && local < saturdayCutoff) return false;

  return !inHoliday;
};

/**
 * Adds a given number of working days to a start date (in Italy time).
 * Skips weekends and holiday ranges as defined by AC38.
 *
 * @param start - A Luxon DateTime object
 * @param count - Number of working days to add
 * @param setTo8pm - If true, sets time to 8:00 PM on the result day
 * @returns The resulting DateTime after skipping non-working days
 */
export const addWorkingDays = (
  start: DateTime,
  count: number,
  setTo8pm: boolean = false
): DateTime => {
  let dt = start.setZone(ROME_TZ);
  let added = 0;

  while (added < count) {
    dt = dt.plus({days: 1});
    if (isWorkingDay(dt)) added++;
  }

  return setTo8pm
    ? dt.set({hour: 20, minute: 0, second: 0, millisecond: 0})
    : dt;
};
