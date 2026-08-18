import { __ } from '~/locale';
import { getWeekdayNames } from '~/lib/utils/datetime_utility';
import { DAILY } from '../constants';
import { TIME_UNITS } from '../../shared/duration_selector/constants';

export const DEFAULT_TIMEZONE = 'Etc/UTC';
export const DEFAULT_START_WEEKDAY = 'Monday';
export const DEFAULT_START_MONTH_DAY = 1;
export const WEEKLY = 'weekly';
export const MONTHLY = 'monthly';

export const CADENCE_OPTIONS = [
  { value: DAILY, text: __('Daily') },
  { value: WEEKLY, text: __('Weekly') },
  { value: MONTHLY, text: __('Monthly') },
];

export const CADENCE_CONFIG = {
  [DAILY]: {
    time_window: { value: TIME_UNITS.MINUTE },
  },
  [WEEKLY]: {
    days: [DEFAULT_START_WEEKDAY],
    time_window: { value: TIME_UNITS.DAY },
  },
  [MONTHLY]: {
    days_of_month: [DEFAULT_START_MONTH_DAY],
    time_window: { value: TIME_UNITS.DAY },
  },
};

/**
 * Time options in one hour increments for the daily scheduler
 * @returns {Array} Array of time options
 */
export const HOUR_MINUTE_LIST = Array.from(Array(24).keys()).map((num) => {
  const hour = num.toString().length === 1 ? `0${num}:00` : `${num}:00`;
  return { value: hour, text: hour };
});

/**
 * Weekday options for the weekly scheduler
 * @returns {Array} Array of weekday options
 */
export const WEEKDAY_OPTIONS = getWeekdayNames().map((day) => {
  return { value: day, text: day };
});

export const MAX_SCHEDULE_BRANCHES = 5;
