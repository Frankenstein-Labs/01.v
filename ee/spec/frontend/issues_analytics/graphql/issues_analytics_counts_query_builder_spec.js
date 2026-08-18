import { print } from 'graphql/language/printer';
import issuesAnalyticsCountsQueryBuilder from 'ee/issues_analytics/graphql/issues_analytics_counts_query_builder';
import {
  ISSUES_ANALYTICS_METRIC_TYPES,
  ISSUES_COMPLETED_COUNT_ALIAS,
  ISSUES_OPENED_COUNT_ALIAS,
} from 'ee/issues_analytics/constants';
import {
  mockIssuesAnalyticsCountsStartDate,
  mockIssuesAnalyticsCountsEndDate,
  getMockIssuesAnalyticsCountsQuery,
} from '../mock_data';

describe('issuesAnalyticsCountsQueryBuilder', () => {
  const startDate = mockIssuesAnalyticsCountsStartDate;
  const endDate = mockIssuesAnalyticsCountsEndDate;

  describe.each([ISSUES_OPENED_COUNT_ALIAS, ISSUES_COMPLETED_COUNT_ALIAS])(
    '%s query',
    (queryAlias) => {
      const metricType = ISSUES_ANALYTICS_METRIC_TYPES[queryAlias];

      it('returns the query for a group as expected', () => {
        const query = issuesAnalyticsCountsQueryBuilder({
          queryAlias,
          startDate,
          endDate,
        });

        expect(print(query)).toEqual(getMockIssuesAnalyticsCountsQuery({ queryAlias, metricType }));
      });

      it('returns the query for a project as expected', () => {
        const isProject = true;
        const query = issuesAnalyticsCountsQueryBuilder({
          queryAlias,
          startDate,
          endDate,
          isProject,
        });

        expect(print(query)).toEqual(
          getMockIssuesAnalyticsCountsQuery({ queryAlias, metricType, isProject }),
        );
      });
    },
  );
});
