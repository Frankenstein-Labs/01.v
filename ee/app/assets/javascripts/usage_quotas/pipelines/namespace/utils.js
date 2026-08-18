import { dateToYearMonthDate, newDate } from '~/lib/utils/datetime_utility';

/**
 * GraphQL data type for namespace_ci_minutes_usage.query.graphql
 *
 * @typedef {object} CiMinutesNamespaceMonthlyUsage
 * @property {string} month
 * @property {string} monthIso8601
 * @property {number} minutes
 * @property {number} sharedRunnersDuration
 */

/**
 * Parses date and extracts year, month and day from the monthy usage data
 *
 * @param {CiMinutesNamespaceMonthlyUsage} monthlyUsage
 */
const parseMonthData = (monthlyUsage) => {
  const date = newDate(monthlyUsage.monthIso8601);
  const formattedDate = dateToYearMonthDate(date);

  return {
    date,
    ...formattedDate,
    ...monthlyUsage,
  };
};

/**
 * Groups namespace compute minutes usage data by year
 *
 * @param {CiMinutesNamespaceMonthlyUsage[]} ciMinutesUsage
 */
export const groupUsageDataByYear = (ciMinutesUsage) => {
  return ciMinutesUsage.reduce((yearData, monthlyUsage) => {
    const formattedData = parseMonthData(monthlyUsage);

    if (!yearData[formattedData.year]) {
      // eslint-disable-next-line no-param-reassign
      yearData[formattedData.year] = [];
    }

    yearData[formattedData.year].push(formattedData);
    return yearData;
  }, {});
};
