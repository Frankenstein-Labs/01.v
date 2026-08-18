import { cloneDeep } from 'lodash-es';
import fetch from 'ee/analytics/analytics_dashboards/data_sources/contributions';
import ContributionsQuery from 'ee/analytics/contribution_analytics/graphql/contributions.query.graphql';
import { defaultClient } from 'ee/analytics/analytics_dashboards/graphql/client';
import { CONTRIBUTIONS_METRICS } from 'ee/analytics/shared/constants';
import { contributionAnalyticsFixture } from 'ee_jest/analytics/contribution_analytics/mock_data';

describe('contributions data source', () => {
  const mockNamespace = 'group/project';
  const mockStartDate = '2024-01-01';
  const mockEndDate = '2024-01-31';
  const mockFilters = {
    startDate: new Date(mockStartDate),
    endDate: new Date(mockEndDate),
  };
  const mockDataSourceClickhouse = true;

  const mockNextPageResponse = {
    data: {
      group: {
        contributions: {
          nodes: [
            {
              repoPushed: 24,
              mergeRequestsCreated: 2,
              mergeRequestsMerged: 2,
              mergeRequestsClosed: 0,
              mergeRequestsApproved: 1,
              issuesCreated: 0,
              issuesClosed: 0,
              totalEvents: 29,
              user: {
                id: 'gid://gitlab/User/123',
                name: 'User 1',
                webUrl: 'https://gitlab.com/user1',
                __typename: 'UserCore',
              },
              __typename: 'ContributionAnalyticsContribution',
            },
          ],
        },
      },
    },
  };

  const mockApiResponse = ({ response = contributionAnalyticsFixture, endCursor = '' } = {}) => {
    const responseCopy = cloneDeep(response);

    responseCopy.data.group.contributions.pageInfo = {
      endCursor,
      hasNextPage: endCursor !== '',
    };

    return responseCopy;
  };

  const mockResolvedQuery = (response = { ...mockApiResponse() }) =>
    jest.spyOn(defaultClient, 'query').mockResolvedValueOnce(response);

  const expectQueryWithVariables = (variables) =>
    expect(defaultClient.query).toHaveBeenCalledWith(
      expect.objectContaining({
        query: ContributionsQuery,
        variables: expect.objectContaining(variables),
      }),
    );

  describe('fetch', () => {
    describe('default', () => {
      beforeEach(() => {
        mockResolvedQuery();
      });
      it('fetches contributions with correct parameters', async () => {
        await fetch({
          filters: mockFilters,
          namespace: mockNamespace,
          query: { metric: CONTRIBUTIONS_METRICS.PUSHES },
          dataSourceClickhouse: mockDataSourceClickhouse,
        });

        expectQueryWithVariables({
          fullPath: mockNamespace,
          startDate: '2024-01-01',
          endDate: '2024-01-31',
          nextPageCursor: '',
        });
      });

      const pushes = [
        { count: 1, user: 'Aaron' },
        { count: 2, user: 'Bob' },
        { count: 3, user: 'Carl' },
      ];

      const issues = [
        { closed: 1, created: 1, user: 'Aaron' },
        { closed: 2, created: 2, user: 'Bob' },
        { closed: 3, created: 3, user: 'Carl' },
      ];

      const mergeRequests = [
        { closed: 1, created: 1, merged: 1, user: 'Aaron' },
        { closed: 2, created: 2, merged: 2, user: 'Bob' },
        { closed: 3, created: 3, merged: 3, user: 'Carl' },
      ];

      it.each`
        name                       | metric                                         | data
        ${'pushes'}                | ${CONTRIBUTIONS_METRICS.PUSHES}                | ${pushes}
        ${'issues'}                | ${CONTRIBUTIONS_METRICS.ISSUES}                | ${issues}
        ${'merge requests'}        | ${CONTRIBUTIONS_METRICS.MERGE_REQUESTS}        | ${mergeRequests}
        ${'contributions by user'} | ${CONTRIBUTIONS_METRICS.CONTRIBUTIONS_BY_USER} | ${contributionAnalyticsFixture.data.group.contributions.nodes}
      `('parses the $name response correctly when metric is $metric', async ({ metric, data }) => {
        const res = await fetch({
          filters: mockFilters,
          namespace: mockNamespace,
          query: { metric },
          dataSourceClickhouse: mockDataSourceClickhouse,
        });

        expect(res).toEqual(data);
      });
    });

    describe('pagination', () => {
      it('handles pagination', async () => {
        // page 1
        mockResolvedQuery(mockApiResponse({ endCursor: 'abc' }));
        // page 2
        mockResolvedQuery(
          mockApiResponse({
            endCursor: '',
            response: mockNextPageResponse,
          }),
        );

        const res = await fetch({
          filters: mockFilters,
          namespace: mockNamespace,
          query: { metric: CONTRIBUTIONS_METRICS.CONTRIBUTIONS_BY_USER },
          dataSourceClickhouse: mockDataSourceClickhouse,
        });

        expect(defaultClient.query).toHaveBeenCalledTimes(2);

        expect(res).toEqual([
          ...contributionAnalyticsFixture.data.group.contributions.nodes,
          ...mockNextPageResponse.data.group.contributions.nodes,
        ]);
      });
    });

    describe('when dataSourceClickhouse = false', () => {
      it('restricts the date range in smaller ranges', async () => {
        // first week
        mockResolvedQuery();
        // second week
        mockResolvedQuery(
          mockApiResponse({
            response: mockNextPageResponse,
          }),
        );

        const res = await fetch({
          filters: {
            startDate: new Date('2024-01-01'),
            endDate: new Date('2024-01-14'),
          },
          namespace: mockNamespace,
          query: { metric: CONTRIBUTIONS_METRICS.MERGE_REQUESTS },
          dataSourceClickhouse: false,
        });

        expect(defaultClient.query).toHaveBeenCalledTimes(2);
        expectQueryWithVariables({
          fullPath: mockNamespace,
          startDate: '2024-01-01',
          endDate: '2024-01-08',
          nextPageCursor: '',
        });
        expectQueryWithVariables({
          fullPath: mockNamespace,
          startDate: '2024-01-09',
          endDate: '2024-01-14',
          nextPageCursor: '',
        });

        expect(res).toEqual([
          { closed: 1, created: 1, merged: 1, user: 'Aaron' },
          { closed: 2, created: 2, merged: 2, user: 'Bob' },
          { closed: 3, created: 3, merged: 3, user: 'Carl' },
          { closed: 0, created: 2, merged: 2, user: 'User 1' },
        ]);
      });
    });
  });
});
