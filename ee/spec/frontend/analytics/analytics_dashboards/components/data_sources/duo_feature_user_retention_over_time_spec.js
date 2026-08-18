import mockDuoFeatureRetentionResponse from 'test_fixtures/ee/graphql/analytics/analytics_dashboards/graphql/queries/get_duo_feature_retention.query.graphql.json';
import mockDuoFeatureRetentionEmptyResponse from 'test_fixtures/ee/graphql/analytics/analytics_dashboards/graphql/queries/get_duo_feature_retention.query.graphql.empty.json';
import duoFeatureUserRetentionOverTime, {
  asFeatureRetentionSeries,
} from 'ee/analytics/analytics_dashboards/data_sources/duo_feature_user_retention_over_time';
import { defaultClient } from 'ee/analytics/analytics_dashboards/graphql/client';
import {
  DATE_RANGE_OPTION_LAST_180_DAYS,
  DATE_RANGE_OPTION_LAST_30_DAYS,
} from 'ee/analytics/analytics_dashboards/components/filters/constants';

describe('`Duo feature user retention over time` data source', () => {
  let res;

  const namespace = 'test-namespace';

  const fetch = (args = {}) =>
    duoFeatureUserRetentionOverTime({
      namespace,
      query: { dateRange: DATE_RANGE_OPTION_LAST_180_DAYS },
      ...args,
    });

  const mockResolvedQuery = (response = mockDuoFeatureRetentionResponse) =>
    jest.spyOn(defaultClient, 'query').mockResolvedValue(response);

  const seriesByName = () => Object.fromEntries(res.map(({ name, data }) => [name, data]));

  const retentionNode = ({
    feature,
    timestamp,
    returningUsersCount,
    previousPeriodUsersCount,
  }) => ({
    dimensions: { feature, timestamp },
    returningUsersCount,
    previousPeriodUsersCount,
  });

  const pageResponse = ({ nodes, hasNextPage = false, endCursor = null }) => ({
    data: {
      group: {
        id: 'gid://gitlab/Group/1',
        analytics: {
          duoUsageEvents: { aggregated: { pageInfo: { hasNextPage, endCursor }, nodes } },
        },
      },
      project: null,
    },
  });

  describe('fetch', () => {
    describe('with data available', () => {
      beforeEach(async () => {
        mockResolvedQuery();
        res = await fetch();
      });

      it('fetches data once with the default features, weekly granularity and resolved date range', () => {
        expect(defaultClient.query).toHaveBeenCalledTimes(1);
        expect(defaultClient.query).toHaveBeenCalledWith(
          expect.objectContaining({
            variables: {
              fullPath: namespace,
              startDate: new Date('2020-01-08'),
              endDate: new Date('2020-07-06'),
              granularity: 'weekly',
              feature: ['code_suggestions', 'chat', 'troubleshoot_job', 'code_review'],
              after: null,
            },
          }),
        );
      });

      it('returns one labelled series per feature', () => {
        expect(res).toHaveLength(2);
        expect(res.map(({ name }) => name)).toEqual(
          expect.arrayContaining(['Code Suggestions', 'Duo Chat']),
        );
      });

      it('plots retention as returning / previous-period users, omitting the first period', () => {
        // code_suggestions: the first week (no previous period) is dropped; week two returns 1 of 2 => 0.5
        expect(seriesByName()['Code Suggestions']).toEqual([[new Date('2020-06-08'), 0.5]]);
        // chat: the first week (no previous period) is dropped; week two returns 1 of 1 => 1
        expect(seriesByName()['Duo Chat']).toEqual([[new Date('2020-06-08'), 1]]);
      });
    });

    describe('with no data available', () => {
      beforeEach(async () => {
        mockResolvedQuery(mockDuoFeatureRetentionEmptyResponse);
        res = await fetch();
      });

      it('returns an empty array', () => {
        expect(res).toEqual([]);
      });
    });

    describe('with only one period available for each feature', () => {
      beforeEach(async () => {
        mockResolvedQuery(
          pageResponse({
            nodes: [
              retentionNode({
                feature: 'code_suggestions',
                timestamp: '2020-06-01T00:00:00Z',
                returningUsersCount: 0,
                previousPeriodUsersCount: 0,
              }),
              retentionNode({
                feature: 'chat',
                timestamp: '2020-06-01T00:00:00Z',
                returningUsersCount: 0,
                previousPeriodUsersCount: 0,
              }),
            ],
          }),
        );
        res = await fetch();
      });

      it('returns an empty array', () => {
        expect(res).toEqual([]);
      });
    });

    describe('when only some features have comparable periods', () => {
      beforeEach(async () => {
        mockResolvedQuery(
          pageResponse({
            nodes: [
              retentionNode({
                feature: 'code_suggestions',
                timestamp: '2020-06-01T00:00:00Z',
                returningUsersCount: 0,
                previousPeriodUsersCount: 0,
              }),
              retentionNode({
                feature: 'chat',
                timestamp: '2020-06-01T00:00:00Z',
                returningUsersCount: 0,
                previousPeriodUsersCount: 0,
              }),
              retentionNode({
                feature: 'chat',
                timestamp: '2020-06-08T00:00:00Z',
                returningUsersCount: 1,
                previousPeriodUsersCount: 2,
              }),
            ],
          }),
        );
        res = await fetch();
      });

      it('omits series without retention data', () => {
        expect(res).toEqual([
          {
            name: 'Duo Chat',
            data: [[new Date('2020-06-08T00:00:00Z'), 0.5]],
          },
        ]);
      });
    });

    describe('when the results span multiple pages', () => {
      beforeEach(async () => {
        jest
          .spyOn(defaultClient, 'query')
          .mockResolvedValueOnce(
            pageResponse({
              nodes: [
                retentionNode({
                  feature: 'code_suggestions',
                  timestamp: '2020-06-01T00:00:00Z',
                  returningUsersCount: 0,
                  previousPeriodUsersCount: 0,
                }),
              ],
              hasNextPage: true,
              endCursor: 'CURSOR_1',
            }),
          )
          .mockResolvedValueOnce(
            pageResponse({
              nodes: [
                retentionNode({
                  feature: 'code_suggestions',
                  timestamp: '2020-06-08T00:00:00Z',
                  returningUsersCount: 1,
                  previousPeriodUsersCount: 2,
                }),
              ],
              hasNextPage: false,
            }),
          );
        res = await fetch();
      });

      it('pages through the cursor until the connection is exhausted', () => {
        expect(defaultClient.query).toHaveBeenCalledTimes(2);
        expect(defaultClient.query).toHaveBeenNthCalledWith(
          1,
          expect.objectContaining({ variables: expect.objectContaining({ after: null }) }),
        );
        expect(defaultClient.query).toHaveBeenNthCalledWith(
          2,
          expect.objectContaining({ variables: expect.objectContaining({ after: 'CURSOR_1' }) }),
        );
      });

      it('merges nodes from every page into the series, omitting the first period', () => {
        // page one is the first period (dropped); page two: 1 of 2 returned => 0.5
        expect(seriesByName()['Code Suggestions']).toEqual([
          [new Date('2020-06-08T00:00:00Z'), 0.5],
        ]);
      });
    });

    describe('with a different date range', () => {
      beforeEach(async () => {
        mockResolvedQuery();
        res = await fetch({ query: { dateRange: DATE_RANGE_OPTION_LAST_30_DAYS } });
      });

      it('uses the resolved date range in the query variables', () => {
        expect(defaultClient.query).toHaveBeenCalledWith(
          expect.objectContaining({
            variables: expect.objectContaining({
              fullPath: namespace,
              startDate: new Date('2020-06-06'),
              endDate: new Date('2020-07-06'),
            }),
          }),
        );
      });
    });
  });

  describe('visualization overrides', () => {
    it('sets the subtitle and the feature retention tooltip', async () => {
      const setVisualizationOverrides = jest.fn();
      mockResolvedQuery();

      await fetch({ setVisualizationOverrides });

      expect(setVisualizationOverrides).toHaveBeenCalledWith({
        visualizationOptionOverrides: expect.objectContaining({
          subtitle: expect.any(String),
          tooltip: {
            description:
              'Percentage of users from the previous period who use the feature again in the selected period. %{linkStart}Learn more%{linkEnd}.',
            descriptionLink: expect.stringContaining(
              'user/analytics/duo_and_sdlc_trends#returning-gitlab-duo-users-by-feature',
            ),
          },
        }),
      });
    });
  });

  describe('asFeatureRetentionSeries', () => {
    it('returns an empty array when given no nodes', () => {
      expect(asFeatureRetentionSeries([])).toEqual([]);
    });

    it('builds one labelled series per feature, mapping known feature keys to names', () => {
      const series = asFeatureRetentionSeries([
        retentionNode({
          feature: 'code_suggestions',
          timestamp: '2020-06-01T00:00:00Z',
          returningUsersCount: 3,
          previousPeriodUsersCount: 4,
        }),
        retentionNode({
          feature: 'chat',
          timestamp: '2020-06-01T00:00:00Z',
          returningUsersCount: 1,
          previousPeriodUsersCount: 2,
        }),
      ]);

      expect(series.map(({ name }) => name)).toEqual(['Code Suggestions', 'Duo Chat']);
    });

    it('falls back to the raw feature key for unknown features', () => {
      const series = asFeatureRetentionSeries([
        retentionNode({
          feature: 'mystery_feature',
          timestamp: '2020-06-01T00:00:00Z',
          returningUsersCount: 1,
          previousPeriodUsersCount: 2,
        }),
      ]);

      expect(series[0].name).toBe('mystery_feature');
    });

    it('orders each series by date ascending and computes the retention rate per point', () => {
      const [series] = asFeatureRetentionSeries([
        retentionNode({
          feature: 'chat',
          timestamp: '2020-06-15T00:00:00Z',
          returningUsersCount: 3,
          previousPeriodUsersCount: 4,
        }),
        retentionNode({
          feature: 'chat',
          timestamp: '2020-06-01T00:00:00Z',
          returningUsersCount: 1,
          previousPeriodUsersCount: 2,
        }),
        retentionNode({
          feature: 'chat',
          timestamp: '2020-06-08T00:00:00Z',
          returningUsersCount: 1,
          previousPeriodUsersCount: 1,
        }),
      ]);

      // The earliest period (2020-06-01) is dropped; the rest stay in ascending order.
      expect(series.data).toEqual([
        [new Date('2020-06-08T00:00:00Z'), 1],
        [new Date('2020-06-15T00:00:00Z'), 0.75],
      ]);
    });

    it('omits the first period, which has no previous period to compare against', () => {
      const [series] = asFeatureRetentionSeries([
        retentionNode({
          feature: 'chat',
          timestamp: '2020-06-01T00:00:00Z',
          returningUsersCount: 0,
          previousPeriodUsersCount: 0,
        }),
        retentionNode({
          feature: 'chat',
          timestamp: '2020-06-08T00:00:00Z',
          returningUsersCount: 4,
          previousPeriodUsersCount: 5,
        }),
      ]);

      // Only the second period remains; the leading zero point is dropped.
      expect(series.data).toEqual([[new Date('2020-06-08T00:00:00Z'), 0.8]]);
    });
  });
});
