import codeReviewRequestsByRoleOverTime from 'ee/analytics/analytics_dashboards/data_sources/code_review_requests_by_role_over_time';
import { defaultClient } from 'ee/analytics/analytics_dashboards/graphql/client';
import {
  DATE_RANGE_OPTION_LAST_60_DAYS,
  DATE_RANGE_OPTION_LAST_90_DAYS,
} from 'ee/analytics/analytics_dashboards/components/filters/constants';

describe('`Code review requests by role over time` data source', () => {
  let res;

  const namespace = 'test-namespace';

  const mockCodeReviewMetricsResponse = (response = {}) => ({
    data: {
      group: {
        aiMetrics: {
          codeReview: {
            ...response,
            __typename: 'codeReviewMetrics',
          },
          __typename: 'AiMetrics',
        },
        __typename: 'Group',
      },
    },
  });

  const setVisualizationOverrides = jest.fn();

  const fetch = async (args) => {
    res = await codeReviewRequestsByRoleOverTime({
      namespace,
      query: { dateRange: DATE_RANGE_OPTION_LAST_60_DAYS },
      setVisualizationOverrides,
      ...args,
    });
  };

  const mockResolvedQuery = () =>
    jest.spyOn(defaultClient, 'query').mockResolvedValue(
      mockCodeReviewMetricsResponse({
        requestReviewDuoCodeReviewOnMrByAuthorEventCount: 500,
        requestReviewDuoCodeReviewOnMrByNonAuthorEventCount: 1000,
      }),
    );

  const expectQueryWithVariables = (variables) =>
    expect(defaultClient.query).toHaveBeenCalledWith(
      expect.objectContaining({
        variables: expect.objectContaining(variables),
      }),
    );

  afterEach(() => {
    jest.clearAllMocks();
  });

  describe('fetch', () => {
    describe('with data available', () => {
      beforeEach(() => {
        jest
          .spyOn(defaultClient, 'query')
          .mockResolvedValueOnce(
            mockCodeReviewMetricsResponse({
              requestReviewDuoCodeReviewOnMrByAuthorEventCount: 4500,
              requestReviewDuoCodeReviewOnMrByNonAuthorEventCount: 7800,
            }),
          )
          .mockResolvedValueOnce(
            mockCodeReviewMetricsResponse({
              requestReviewDuoCodeReviewOnMrByAuthorEventCount: 0,
              requestReviewDuoCodeReviewOnMrByNonAuthorEventCount: 0,
            }),
          )
          .mockResolvedValueOnce(
            mockCodeReviewMetricsResponse({
              requestReviewDuoCodeReviewOnMrByAuthorEventCount: 4800,
              requestReviewDuoCodeReviewOnMrByNonAuthorEventCount: 9200,
            }),
          );

        return fetch();
      });

      it('fetches metrics for each time period', () => {
        expect(defaultClient.query).toHaveBeenCalledTimes(3);

        [
          { startDate: '2020-05-07', endDate: '2020-05-31' },
          { startDate: '2020-06-01', endDate: '2020-06-30' },
          { startDate: '2020-07-01', endDate: '2020-07-06' },
        ].forEach(({ startDate, endDate }) => {
          expectQueryWithVariables({
            fullPath: namespace,
            startDate,
            endDate,
          });
        });
      });

      it('returns data series duo code review requests by authors and non-authors', () => {
        expect(res).toEqual({
          bars: [
            {
              name: 'Requests by authors',
              data: [4500, 0, 4800],
            },
            {
              name: 'Requests by non-authors',
              data: [7800, 0, 9200],
            },
          ],
          groupBy: ['May 2020', 'Jun 2020', 'Jul 2020'],
        });
      });

      it('calls `setVisualizationOverrides` with correct tooltip description and link', () => {
        expect(setVisualizationOverrides).toHaveBeenCalledWith({
          visualizationOptionOverrides: expect.objectContaining({
            tooltip: {
              description:
                'Tracks users who initiated GitLab Duo Code Review. %{linkStart}Learn more%{linkEnd}.',
              descriptionLink:
                '/help/user/analytics/duo_and_sdlc_trends#gitlab-duo-code-review-requests-by-role',
            },
          }),
        });
      });
    });
  });

  describe('with no data available', () => {
    beforeEach(() => {
      jest.spyOn(defaultClient, 'query').mockResolvedValue(
        mockCodeReviewMetricsResponse({
          requestReviewDuoCodeReviewOnMrByAuthorEventCount: 0,
          requestReviewDuoCodeReviewOnMrByNonAuthorEventCount: 0,
        }),
      );

      return fetch();
    });

    it('returns an empty object', () => {
      expect(res).toEqual({});
    });
  });

  describe('with unsupported date range', () => {
    it('falls back to fetching data for `LAST_180_DAYS`', async () => {
      mockResolvedQuery();

      await fetch({
        query: { dateRange: '2000d' },
      });

      expect(defaultClient.query).toHaveBeenCalledTimes(7);

      [
        { startDate: '2020-01-08', endDate: '2020-01-31' },
        { startDate: '2020-02-01', endDate: '2020-02-29' },
        { startDate: '2020-03-01', endDate: '2020-03-31' },
        { startDate: '2020-04-01', endDate: '2020-04-30' },
        { startDate: '2020-05-01', endDate: '2020-05-31' },
        { startDate: '2020-06-01', endDate: '2020-06-30' },
        { startDate: '2020-07-01', endDate: '2020-07-06' },
      ].forEach(({ startDate, endDate }) => {
        expectQueryWithVariables({
          fullPath: namespace,
          startDate,
          endDate,
        });
      });
    });
  });

  describe('query overrides', () => {
    it('can override the namespace', async () => {
      mockResolvedQuery();

      await fetch({
        query: { dateRange: DATE_RANGE_OPTION_LAST_60_DAYS, namespace: 'cool-namespace' },
      });

      expect(setVisualizationOverrides).toHaveBeenCalledWith({
        visualizationOptionOverrides: expect.objectContaining({ subtitle: 'Last 60 days' }),
      });

      [
        { startDate: '2020-05-07', endDate: '2020-05-31' },
        { startDate: '2020-06-01', endDate: '2020-06-30' },
        { startDate: '2020-07-01', endDate: '2020-07-06' },
      ].forEach(({ startDate, endDate }) => {
        expectQueryWithVariables({
          fullPath: 'cool-namespace',
          startDate,
          endDate,
        });
      });
    });

    it('can override the date range', async () => {
      mockResolvedQuery();

      await fetch({
        query: { dateRange: DATE_RANGE_OPTION_LAST_90_DAYS },
      });

      expect(setVisualizationOverrides).toHaveBeenCalledWith({
        visualizationOptionOverrides: expect.objectContaining({ subtitle: 'Last 90 days' }),
      });

      [
        { startDate: '2020-04-07', endDate: '2020-04-30' },
        { startDate: '2020-05-01', endDate: '2020-05-31' },
        { startDate: '2020-06-01', endDate: '2020-06-30' },
        { startDate: '2020-07-01', endDate: '2020-07-06' },
      ].forEach(({ startDate, endDate }) => {
        expectQueryWithVariables({
          fullPath: namespace,
          startDate,
          endDate,
        });
      });
    });
  });
});
