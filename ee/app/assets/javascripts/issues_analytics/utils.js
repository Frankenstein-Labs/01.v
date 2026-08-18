import { dateFormats } from '~/analytics/shared/constants';
import dateFormat from '~/lib/dateformat';
import { getMonthNames, cloneDate } from '~/lib/utils/datetime_utility';

/**
 * @typedef {Object} monthDataItem
 * @property {Date} fromDate
 * @property {Date} toDate
 * @property {String} month - abbreviated month
 * @property {Number} year
 */

/**
 * Accepts a date range and an Issue Analytics count query type and
 * generates the data needed to build the GraphQL query for the chart
 *
 * @param startDate - start date for the date range
 * @param endDate - end date for the date range
 * @param format - format to be used by date range
 * @return {monthDataItem[]} - date range data
 */
export const generateChartDateRangeData = (startDate, endDate, format = dateFormats.isoDate) => {
  const chartDateRangeData = [];
  const abbrMonthNames = getMonthNames(true);
  const formatDate = (date) => dateFormat(date, format, true);

  for (
    let fromDate = cloneDate(startDate);
    fromDate < endDate;
    fromDate.setMonth(fromDate.getMonth() + 1, 1)
  ) {
    let toDate = cloneDate(fromDate);
    toDate.setMonth(toDate.getMonth() + 1, 1);
    if (toDate > endDate) toDate = endDate;

    chartDateRangeData.push({
      fromDate: formatDate(fromDate),
      toDate: formatDate(toDate),
      month: abbrMonthNames[fromDate.getMonth()],
      year: fromDate.getFullYear(),
      identifier: `query_${fromDate.getFullYear()}_${fromDate.getMonth() + 1}`,
    });
  }

  return chartDateRangeData;
};
