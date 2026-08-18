import { gql } from '@apollo/client/core';
import { generateChartDateRangeData } from 'ee/issues_analytics/utils';
import { ISSUES_ANALYTICS_METRIC_TYPES } from 'ee/issues_analytics/constants';

/**
 * A GraphQL query building function which accepts a
 * queryAlias, startDate and endDate, returning a parsed query string
 * which nests sub-queries for the number of issues opened/closed
 * per month at the group or project level.
 *
 * @param queryInfo - Information needed to build the Issues Analytics counts query
 * @param {"issuesOpenedCounts" | "issuesClosedCounts"} queryInfo.queryAlias - query alias used to prevent name clashing and to fetch the correct Issue Analytics metric type
 * @param {Date} queryInfo.startDate - the startDate for the date range
 * @param {Date} queryInfo.endDate - the endDate for the date range
 * @param {Boolean} queryInfo.isProject - is it a Project query type
 *
 * @return {String} the parsed GraphQL query string
 */
export default ({ queryAlias, startDate = null, endDate = null, isProject = false } = {}) => {
  const dateRangeData = generateChartDateRangeData(startDate, endDate);

  if (!dateRangeData.length) return '';

  const countsByMonth = dateRangeData.map(
    ({ fromDate, toDate, identifier }) => `
      ${identifier}: ${ISSUES_ANALYTICS_METRIC_TYPES[queryAlias]}(
        from: "${fromDate}",
        to: "${toDate}"
        assigneeUsernames: $assigneeUsernames
        authorUsername: $authorUsername
        milestoneTitle: $milestoneTitle
        labelNames: $labelNames
        epicId: $epicId
        iterationId: $iterationId
        myReactionEmoji: $myReactionEmoji
        weight: $weight
        not: $not
        ) { value }
    `,
  );

  return gql`
    query get${queryAlias}($fullPath: ID!, $assigneeUsernames: [String!], $authorUsername: String, $milestoneTitle: String, $labelNames: [String!], $epicId: ID, $iterationId: ID, $myReactionEmoji: String, $weight: Int, $not: NegatedValueStreamAnalyticsIssuableFilterInput) {
      namespace: ${isProject ? 'project' : 'group'}(fullPath: $fullPath) {
        id
        ${queryAlias}: flowMetrics {
            ${countsByMonth}
        }
      }
    }
  `;
};
