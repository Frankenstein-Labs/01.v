import { s__ } from '~/locale';
import {
  getStartOfDay,
  nDaysBefore,
  nMonthsBefore,
} from '~/lib/utils/datetime/date_calculation_utility';
import { toISODateFormat } from '~/lib/utils/datetime/date_format_utility';

const UTC = { utc: true };

function utcFirstDayOfMonth(date) {
  return new Date(Date.UTC(date.getUTCFullYear(), date.getUTCMonth(), 1));
}

function utcLastDayOfMonth(date) {
  return new Date(Date.UTC(date.getUTCFullYear(), date.getUTCMonth() + 1, 0));
}

export const TODAY = getStartOfDay(new Date(), UTC);

const firstOfThisMonth = utcFirstDayOfMonth(TODAY);
const firstOfLastMonth = utcFirstDayOfMonth(nMonthsBefore(TODAY, 1, UTC));

export const THIS_MONTH = Object.freeze({
  value: 'this_month',
  text: s__('DateRangeFilter|This month'),
  startDate: toISODateFormat(firstOfThisMonth, true),
  endDate: toISODateFormat(utcLastDayOfMonth(firstOfThisMonth), true),
});

export const LAST_MONTH = Object.freeze({
  value: 'last_month',
  text: s__('DateRangeFilter|Last month'),
  startDate: toISODateFormat(firstOfLastMonth, true),
  endDate: toISODateFormat(utcLastDayOfMonth(firstOfLastMonth), true),
});

export const LAST_7_DAYS = Object.freeze({
  value: 'last_7_days',
  text: s__('DateRangeFilter|Last 7 days'),
  startDate: toISODateFormat(nDaysBefore(TODAY, 7, UTC), true),
  endDate: toISODateFormat(TODAY, true),
});

export const LAST_30_DAYS = Object.freeze({
  value: 'last_30_days',
  text: s__('DateRangeFilter|Last 30 days'),
  startDate: toISODateFormat(nDaysBefore(TODAY, 30, UTC), true),
  endDate: toISODateFormat(TODAY, true),
});

export const CUSTOM = {
  value: 'custom',
  text: s__('DateRangeFilter|Custom'),
};
