import codeGenerationVolumeOverTime from 'ee/analytics/analytics_dashboards/data_sources/code_generation_volume_over_time';
import { defaultClient } from 'ee/analytics/analytics_dashboards/graphql/client';
import {
  DATE_RANGE_OPTION_LAST_60_DAYS,
  DATE_RANGE_OPTION_LAST_30_DAYS,
} from 'ee/analytics/analytics_dashboards/components/filters/constants';

describe('`Code generation volume over time` data source', () => {
  let res;

  const title = 'Code generation volume';
  const namespace = 'test-namespace';

  const setVisualizationOverrides = jest.fn();

  const mockCodeSuggestionsResponse = (response = {}) => ({
    data: {
      group: {
        aiMetrics: {
          codeSuggestions: {
            ...response,
            __typename: 'codeSuggestionMetrics',
          },
          __typename: 'AiMetrics',
        },
        __typename: 'Group',
      },
    },
  });

  const mockCodeGenerationVolumeTrendsData = [
    {
      data: [
        ['May 2020', 3],
        ['Jun 2020', 0],
        ['Jul 2020', 20],
      ],
      name: 'Lines of code accepted',
    },
    {
      data: [
        ['May 2020', 10],
        ['Jun 2020', 0],
        ['Jul 2020', 100],
      ],
      name: 'Lines of code shown',
    },
  ];

  const fetch = async (args) => {
    res = await codeGenerationVolumeOverTime({
      title,
      namespace,
      query: { dateRange: DATE_RANGE_OPTION_LAST_60_DAYS },
      setVisualizationOverrides,
      ...args,
    });
  };

  const mockResolvedQuery = () =>
    jest
      .spyOn(defaultClient, 'query')
      .mockResolvedValue(
        mockCodeSuggestionsResponse({ acceptedLinesOfCode: 500, shownLinesOfCode: 1000 }),
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
            mockCodeSuggestionsResponse({ acceptedLinesOfCode: 3, shownLinesOfCode: 10 }),
          )
          .mockResolvedValueOnce(
            mockCodeSuggestionsResponse({ acceptedLinesOfCode: null, shownLinesOfCode: null }),
          )
          .mockResolvedValueOnce(
            mockCodeSuggestionsResponse({ acceptedLinesOfCode: 20, shownLinesOfCode: 100 }),
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

      it('returns data series for accepted and shown lines of code', () => {
        expect(res).toEqual(mockCodeGenerationVolumeTrendsData);
      });

      it('calls `setVisualizationOverrides` with correct tooltip description and link', () => {
        expect(setVisualizationOverrides).toHaveBeenCalledWith({
          visualizationOptionOverrides: expect.objectContaining({
            tooltip: {
              description:
                'Tracks lines of code accepted and shown from GitLab Duo Code Suggestions. %{linkStart}Learn more%{linkEnd}.',
              descriptionLink:
                '/help/user/analytics/duo_and_sdlc_trends#code-generation-volume-trends',
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
        query: { dateRange: DATE_RANGE_OPTION_LAST_30_DAYS },
      });

      expect(setVisualizationOverrides).toHaveBeenCalledWith({
        visualizationOptionOverrides: expect.objectContaining({ subtitle: 'Last 30 days' }),
      });

      [
        { startDate: '2020-06-06', endDate: '2020-06-30' },
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
