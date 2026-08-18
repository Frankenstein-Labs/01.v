import codeReviewSentimentOverTime from 'ee/analytics/analytics_dashboards/data_sources/code_review_comments_sentiment_over_time';
import { defaultClient } from 'ee/analytics/analytics_dashboards/graphql/client';
import {
  DATE_RANGE_OPTION_LAST_60_DAYS,
  DATE_RANGE_OPTION_LAST_7_DAYS,
} from 'ee/analytics/analytics_dashboards/components/filters/constants';

describe('`Code review comments sentiment over time` data source', () => {
  let res;

  const title = 'Code review comments sentiment';
  const namespace = 'test-namespace';

  const setVisualizationOverrides = jest.fn();
  const mockCodeReviewResponse = (response = {}) => ({
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

  const mockCodeReviewCommentsSentimentData = [
    {
      data: [
        ['May 2020', 0.5],
        ['Jun 2020', 0],
        ['Jul 2020', 0.2],
      ],
      name: '👍 Approval rate',
    },
    {
      data: [
        ['May 2020', 0.1],
        ['Jun 2020', 0],
        ['Jul 2020', 0.5],
      ],
      name: '👎 Disapproval rate',
    },
  ];

  const fetch = async (args) => {
    res = await codeReviewSentimentOverTime({
      title,
      namespace,
      setVisualizationOverrides,
      query: { dateRange: DATE_RANGE_OPTION_LAST_60_DAYS },
      ...args,
    });
  };

  const mockResolvedQuery = () =>
    jest.spyOn(defaultClient, 'query').mockResolvedValue(
      mockCodeReviewResponse({
        postCommentDuoCodeReviewOnDiffEventCount: 2000,
        reactThumbsDownOnDuoCodeReviewCommentEventCount: 500,
        reactThumbsUpOnDuoCodeReviewCommentEventCount: 1000,
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
            mockCodeReviewResponse({
              postCommentDuoCodeReviewOnDiffEventCount: 30,
              reactThumbsDownOnDuoCodeReviewCommentEventCount: 3,
              reactThumbsUpOnDuoCodeReviewCommentEventCount: 15,
            }),
          )
          .mockResolvedValueOnce(
            mockCodeReviewResponse({
              postCommentDuoCodeReviewOnDiffEventCount: 0,
              reactThumbsDownOnDuoCodeReviewCommentEventCount: null,
              reactThumbsUpOnDuoCodeReviewCommentEventCount: null,
            }),
          )
          .mockResolvedValueOnce(
            mockCodeReviewResponse({
              postCommentDuoCodeReviewOnDiffEventCount: 100,
              reactThumbsDownOnDuoCodeReviewCommentEventCount: 50,
              reactThumbsUpOnDuoCodeReviewCommentEventCount: 20,
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

      it('returns data series for code review comment approval and disapproval rates', () => {
        expect(res).toEqual(mockCodeReviewCommentsSentimentData);
      });

      it('calls `setVisualizationOverrides` with correct chart options and tooltip', () => {
        expect(setVisualizationOverrides).toHaveBeenCalledWith({
          visualizationOptionOverrides: expect.objectContaining({
            tooltip: {
              description:
                'Users that reacted positively or negatively to GitLab Duo Code review comments. Expect negativity bias. %{linkStart}Learn more%{linkEnd}.',
              descriptionLink:
                '/help/user/analytics/duo_and_sdlc_trends#gitlab-duo-code-review-comments-sentiment',
            },
            yAxis: {
              axisLabel: {
                formatter: expect.any(Function),
              },
            },
          }),
        });
      });
    });
  });

  describe('with no data available', () => {
    beforeEach(() => {
      jest.spyOn(defaultClient, 'query').mockResolvedValue({ data: {} });

      return fetch();
    });

    it('returns an empty array', () => {
      expect(res).toEqual([]);
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
        query: { dateRange: DATE_RANGE_OPTION_LAST_7_DAYS },
      });

      expect(setVisualizationOverrides).toHaveBeenCalledWith({
        visualizationOptionOverrides: expect.objectContaining({ subtitle: 'Last 7 days' }),
      });

      [
        { startDate: '2020-06-29', endDate: '2020-06-30' },
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
