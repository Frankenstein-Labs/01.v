import mockDuoPipelinesRateResponseData from 'test_fixtures/ee/graphql/analytics/dashboards/ai_impact/graphql/duo_pipelines_rate.query.graphql.json';
import mockDuoPipelinesRatePreviousResponseData from 'test_fixtures/ee/graphql/analytics/dashboards/ai_impact/graphql/duo_pipelines_rate.query.graphql.previous.json';
import mockDuoPipelinesRateEmptyResponseData from 'test_fixtures/ee/graphql/analytics/dashboards/ai_impact/graphql/duo_pipelines_rate.query.graphql.empty.json';
import mockAiMetricsZeroResponseData from 'test_fixtures/ee/graphql/analytics/dashboards/ai_impact/graphql/ai_metrics.query.graphql.zero_values.json';
import mockAiMetricsNullResponseData from 'test_fixtures/ee/graphql/analytics/dashboards/ai_impact/graphql/ai_metrics.query.graphql.null_values.json';
import mockAiMetricsResponseData from 'test_fixtures/ee/graphql/analytics/dashboards/ai_impact/graphql/ai_metrics.query.graphql.json';
import mockAiMetricsPreviousResponseData from 'test_fixtures/ee/graphql/analytics/dashboards/ai_impact/graphql/ai_metrics.query.graphql.column_2.json';
import mockAgentFlowsUsersCountResponseData from 'test_fixtures/ee/graphql/analytics/dashboards/ai_impact/graphql/duo_agent_platform_agent_flows_users_count.query.graphql.json';
import mockAgentFlowsUsersCountPreviousResponseData from 'test_fixtures/ee/graphql/analytics/dashboards/ai_impact/graphql/duo_agent_platform_agent_flows_users_count.query.graphql.previous.json';
import mockDuoPowerUsersCountResponseData from 'test_fixtures/ee/graphql/analytics/dashboards/ai_impact/graphql/duo_power_users_count.query.graphql.json';
import mockDuoPowerUsersCountPreviousResponseData from 'test_fixtures/ee/graphql/analytics/dashboards/ai_impact/graphql/duo_power_users_count.query.graphql.previous.json';
import { AI_METRICS } from '~/analytics/shared/constants';
import fetch from 'ee/analytics/analytics_dashboards/data_sources/ai_impact_over_time';
import { defaultClient } from 'ee/analytics/analytics_dashboards/graphql/client';
import {
  DATE_RANGE_OPTION_LAST_7_DAYS,
  DATE_RANGE_OPTION_LAST_30_DAYS,
} from 'ee/analytics/analytics_dashboards/components/filters/constants';
import DuoUsedCountQuery from '~/analytics/dashboards/ai_impact/graphql/duo_used_count.query.graphql';
import DuoAgentPlatformChatsQuery from '~/analytics/dashboards/ai_impact/graphql/duo_agent_platform_chats.query.graphql';
import DuoAgentPlatformAgentFlowsUsersCountQuery from '~/analytics/dashboards/ai_impact/graphql/duo_agent_platform_agent_flows_users_count.query.graphql';
import DuoPowerUsersCountQuery from '~/analytics/dashboards/ai_impact/graphql/duo_power_users_count.query.graphql';
import DuoPipelinesRateQuery from '~/analytics/dashboards/ai_impact/graphql/duo_pipelines_rate.query.graphql';

const INVALID_DATE_RANGE = 'invalid-range';

describe('AI Impact Over Time Data Source', () => {
  let res;

  const query = {
    metric: AI_METRICS.DUO_USED_COUNT,
    dateRange: DATE_RANGE_OPTION_LAST_30_DAYS,
  };
  const namespace = 'cool namespace';
  const defaultParams = {
    namespace,
    query,
  };

  const mockResolvedQuery = (
    current = mockAiMetricsResponseData,
    previous = mockAiMetricsPreviousResponseData,
  ) =>
    jest
      .spyOn(defaultClient, 'query')
      .mockResolvedValueOnce(current)
      .mockResolvedValueOnce(previous);

  const expectQueryWithVariables = (variables) =>
    expect(defaultClient.query).toHaveBeenCalledWith(
      expect.objectContaining({
        variables: expect.objectContaining(variables),
      }),
    );

  describe('fetch', () => {
    describe('default', () => {
      describe.each`
        dateRange    | startDate       | prevStartDate   | prevEndDate
        ${undefined} | ${'2020-06-06'} | ${'2020-05-06'} | ${'2020-06-05'}
        ${'invalid'} | ${'2020-06-06'} | ${'2020-05-06'} | ${'2020-06-05'}
        ${'30d'}     | ${'2020-06-06'} | ${'2020-05-06'} | ${'2020-06-05'}
        ${'7d'}      | ${'2020-06-29'} | ${'2020-06-21'} | ${'2020-06-28'}
        ${'60d'}     | ${'2020-05-07'} | ${'2020-03-07'} | ${'2020-05-06'}
        ${'90d'}     | ${'2020-04-07'} | ${'2020-01-07'} | ${'2020-04-06'}
        ${'180d'}    | ${'2020-01-08'} | ${'2019-07-11'} | ${'2020-01-07'}
        ${'365d'}    | ${'2019-07-07'} | ${'2018-07-06'} | ${'2019-07-06'}
      `('when dateRange = $dateRange', ({ dateRange, startDate, prevStartDate, prevEndDate }) => {
        beforeEach(async () => {
          mockResolvedQuery();
          res = await fetch({ namespace, query: { ...query, dateRange } });
        });

        it('sends a request for current and previous date ranges', () => {
          expect(defaultClient.query).toHaveBeenCalledTimes(2);
          expectQueryWithVariables({ startDate, endDate: '2020-07-06', fullPath: namespace });
          expectQueryWithVariables({
            startDate: prevStartDate,
            endDate: prevEndDate,
            fullPath: namespace,
          });
        });
      });

      it.each`
        metric                                                    | expectedQuery
        ${AI_METRICS.DUO_USED_COUNT}                              | ${DuoUsedCountQuery}
        ${AI_METRICS.DUO_AGENT_PLATFORM_CHATS}                    | ${DuoAgentPlatformChatsQuery}
        ${AI_METRICS.DUO_AGENT_PLATFORM_AGENTS_FLOWS_USERS_COUNT} | ${DuoAgentPlatformAgentFlowsUsersCountQuery}
        ${AI_METRICS.DUO_POWER_USERS_COUNT}                       | ${DuoPowerUsersCountQuery}
        ${AI_METRICS.DUO_PIPELINES_RATE}                          | ${DuoPipelinesRateQuery}
      `('sends the correct query for `$metric`', async ({ metric, expectedQuery }) => {
        mockResolvedQuery();
        await fetch({ namespace, query: { ...query, metric } });

        expect(defaultClient.query).toHaveBeenCalledWith(
          expect.objectContaining({ query: expectedQuery }),
        );
      });

      describe.each`
        type             | response                         | result
        ${'valid'}       | ${mockAiMetricsResponseData}     | ${'3'}
        ${'zero values'} | ${mockAiMetricsZeroResponseData} | ${'0'}
        ${'null values'} | ${mockAiMetricsNullResponseData} | ${'-'}
      `('with $type data', ({ response, result }) => {
        beforeEach(async () => {
          mockResolvedQuery(response);
          res = await fetch({ namespace, query });
        });

        it(`returns ${result}`, () => {
          expect(res).toBe(result);
        });
      });
    });

    describe('setVisualizationOverrides callback', () => {
      let mockSetVisualizationOverrides;

      beforeEach(() => {
        mockSetVisualizationOverrides = jest.fn();
      });

      describe.each`
        metric
        ${AI_METRICS.DUO_AGENT_PLATFORM_CHATS}
        ${AI_METRICS.DUO_USED_COUNT}
      `('for $metric metric', ({ metric }) => {
        beforeEach(async () => {
          mockResolvedQuery();
          res = await fetch({
            namespace,
            query: { ...defaultParams.query, metric },
            setVisualizationOverrides: mockSetVisualizationOverrides,
          });
        });

        it('will call the setVisualizationOverrides callback with the correct settings', () => {
          expect(mockSetVisualizationOverrides.mock.calls).toMatchSnapshot();
        });
      });

      describe(`for ${AI_METRICS.DUO_AGENT_PLATFORM_AGENTS_FLOWS_USERS_COUNT} metric`, () => {
        beforeEach(async () => {
          mockResolvedQuery(
            mockAgentFlowsUsersCountResponseData,
            mockAgentFlowsUsersCountPreviousResponseData,
          );
          res = await fetch({
            namespace,
            query: {
              ...defaultParams.query,
              metric: AI_METRICS.DUO_AGENT_PLATFORM_AGENTS_FLOWS_USERS_COUNT,
            },
            setVisualizationOverrides: mockSetVisualizationOverrides,
          });
        });

        it('will call the setVisualizationOverrides callback with the correct settings', () => {
          expect(mockSetVisualizationOverrides.mock.calls).toMatchSnapshot();
        });
      });

      describe(`for ${AI_METRICS.DUO_POWER_USERS_COUNT} metric`, () => {
        beforeEach(async () => {
          mockResolvedQuery(
            mockDuoPowerUsersCountResponseData,
            mockDuoPowerUsersCountPreviousResponseData,
          );
          res = await fetch({
            namespace,
            query: {
              ...defaultParams.query,
              metric: AI_METRICS.DUO_POWER_USERS_COUNT,
            },
            setVisualizationOverrides: mockSetVisualizationOverrides,
          });
        });

        it('will call the setVisualizationOverrides callback with the correct settings', () => {
          expect(mockSetVisualizationOverrides.mock.calls).toMatchSnapshot();
        });
      });

      describe(`for ${AI_METRICS.DUO_PIPELINES_RATE} metric`, () => {
        const pipelinesRateQuery = {
          ...defaultParams.query,
          metric: AI_METRICS.DUO_PIPELINES_RATE,
        };

        describe('with pipelines data', () => {
          beforeEach(async () => {
            mockResolvedQuery(
              mockDuoPipelinesRateResponseData,
              mockDuoPipelinesRatePreviousResponseData,
            );
            res = await fetch({
              namespace,
              query: pipelinesRateQuery,
              setVisualizationOverrides: mockSetVisualizationOverrides,
            });
          });

          it('returns the percentage of pipelines that used Duo', () => {
            expect(res).toBe('20.0');
          });

          it('will call the setVisualizationOverrides callback with the correct settings', () => {
            expect(mockSetVisualizationOverrides.mock.calls).toMatchSnapshot();
          });
        });

        describe('with no pipelines data', () => {
          beforeEach(async () => {
            mockResolvedQuery(
              mockDuoPipelinesRateEmptyResponseData,
              mockDuoPipelinesRateEmptyResponseData,
            );
            res = await fetch({
              namespace,
              query: pipelinesRateQuery,
              setVisualizationOverrides: mockSetVisualizationOverrides,
            });
          });

          it('returns `-`', () => {
            expect(res).toBe('-');
          });
        });
      });

      it('sets correct `metaTooltip` when previous period has no data', async () => {
        mockResolvedQuery(mockAiMetricsResponseData, mockAiMetricsZeroResponseData);

        await fetch({
          namespace,
          query,
          setVisualizationOverrides: mockSetVisualizationOverrides,
        });

        expect(mockSetVisualizationOverrides).toHaveBeenCalledWith(
          expect.objectContaining({
            visualizationOptionOverrides: expect.objectContaining({
              metaTooltip:
                "Value can't be calculated due to insufficient data. No data is available for the previous time period.",
            }),
          }),
        );
      });
    });

    describe('query overrides', () => {
      const mockQuery = (
        dateRange,
        {
          namespace: namespaceParam = 'cool namespace',
          metric = AI_METRICS.DUO_USED_COUNT,
          response,
        } = {},
      ) => {
        mockResolvedQuery(response);

        return fetch({
          ...defaultParams,
          query: { ...defaultParams.query, metric, dateRange, namespace: namespaceParam },
        });
      };

      it('can override the date range', async () => {
        res = await mockQuery(DATE_RANGE_OPTION_LAST_7_DAYS);

        expectQueryWithVariables({
          startDate: '2020-06-29',
          endDate: '2020-07-06',
          fullPath: namespace,
        });
      });

      it.each`
        metric                                 | result
        ${AI_METRICS.DUO_USED_COUNT}           | ${'3'}
        ${AI_METRICS.DUO_AGENT_PLATFORM_CHATS} | ${'25'}
      `('can override the metric with `$metric`', async ({ metric, result }) => {
        res = await mockQuery(DATE_RANGE_OPTION_LAST_7_DAYS, { metric });

        expectQueryWithVariables({
          startDate: '2020-06-29',
          endDate: '2020-07-06',
          fullPath: namespace,
        });

        expect(res).toBe(result);
      });

      it(`can override the metric with ${AI_METRICS.DUO_AGENT_PLATFORM_AGENTS_FLOWS_USERS_COUNT} metric`, async () => {
        mockResolvedQuery(
          mockAgentFlowsUsersCountResponseData,
          mockAgentFlowsUsersCountPreviousResponseData,
        );
        res = await fetch({
          ...defaultParams,
          query: {
            ...defaultParams.query,
            metric: AI_METRICS.DUO_AGENT_PLATFORM_AGENTS_FLOWS_USERS_COUNT,
            dateRange: DATE_RANGE_OPTION_LAST_7_DAYS,
            namespace,
          },
        });

        expectQueryWithVariables({
          startDate: '2020-06-29',
          endDate: '2020-07-06',
          fullPath: namespace,
        });

        expect(res).toBe('2');
      });

      it(`can override the metric with ${AI_METRICS.DUO_POWER_USERS_COUNT} metric`, async () => {
        mockResolvedQuery(
          mockDuoPowerUsersCountResponseData,
          mockDuoPowerUsersCountPreviousResponseData,
        );
        res = await fetch({
          ...defaultParams,
          query: {
            ...defaultParams.query,
            metric: AI_METRICS.DUO_POWER_USERS_COUNT,
            dateRange: DATE_RANGE_OPTION_LAST_7_DAYS,
            namespace,
          },
        });

        expectQueryWithVariables({
          startDate: '2020-06-29',
          endDate: '2020-07-06',
          fullPath: namespace,
        });

        expect(res).toBe('2');
      });

      it('can override the namespace', async () => {
        res = await mockQuery(DATE_RANGE_OPTION_LAST_7_DAYS, {
          namespace: 'cool-namespace/sub-namespace',
        });

        expectQueryWithVariables({
          startDate: '2020-06-29',
          endDate: '2020-07-06',
          fullPath: 'cool-namespace/sub-namespace',
        });
      });

      it('will default to DATE_RANGE_OPTION_LAST_30_DAYS when given an invalid dateRange', async () => {
        res = await mockQuery(INVALID_DATE_RANGE);

        expectQueryWithVariables({
          startDate: '2020-06-06',
          endDate: '2020-07-06',
          fullPath: namespace,
        });

        const defaultRes = await mockQuery(DATE_RANGE_OPTION_LAST_30_DAYS);
        expect(defaultRes).toEqual(res);
      });
    });

    describe('unsupported metric', () => {
      it('throws an error', async () => {
        await expect(
          fetch({ namespace, query: { ...query, metric: 'unsupported_metric' } }),
        ).rejects.toThrow('No query found for metric: unsupported_metric');
      });
    });
  });
});
