import fetch, { prepareQuery } from 'ee/analytics/analytics_dashboards/data_sources/usage_count';
import {
  USAGE_OVERVIEW_GROUP_ONLY_IDENTIFIERS,
  USAGE_OVERVIEW_IDENTIFIER_ISSUES,
  USAGE_OVERVIEW_IDENTIFIER_PIPELINES,
} from '~/analytics/shared/constants';
import { defaultClient } from 'ee/analytics/analytics_dashboards/graphql/client';
import {
  mockGroupUsageMetricsQueryResponse,
  mockGroupUsageMetricsZeroQueryResponse,
} from 'ee_jest/analytics/analytics_dashboards/mock_data';

describe('Usage count data source', () => {
  let obj;

  const query = { metric: USAGE_OVERVIEW_IDENTIFIER_ISSUES };
  const namespace = 'some-namespace-path';
  const setAlerts = jest.fn();
  const setVisualizationOverrides = jest.fn();
  const overviewCountsAggregationEnabled = true;
  const defaultParams = {
    namespace,
    query,
    setAlerts,
    overviewCountsAggregationEnabled,
  };

  describe('prepareQuery', () => {
    const queryIncludeKeys = [
      'includeGroups',
      'includeProjects',
      'includeUsers',
      'includeIssues',
      'includeMergeRequests',
      'includePipelines',
    ];

    it('will return all the keys we can include', () => {
      expect(Object.keys(prepareQuery())).toEqual(queryIncludeKeys);
    });

    it('will return false for every key by default', () => {
      Object.values(prepareQuery()).forEach((res) => {
        expect(res).toBe(false);
      });
    });

    it('will set key that is explicitly included to true', () => {
      const res = prepareQuery(USAGE_OVERVIEW_IDENTIFIER_ISSUES);

      expect(res).toEqual({
        includeGroups: false,
        includeIssues: true,
        includeProjects: false,
        includeUsers: false,
        includeMergeRequests: false,
        includePipelines: false,
      });
    });
  });

  describe('fetch', () => {
    describe('default', () => {
      beforeEach(() => {
        jest.spyOn(defaultClient, 'query').mockResolvedValue({ data: {} });
      });

      it('will only request the specified metric', async () => {
        obj = await fetch(defaultParams);

        expect(defaultClient.query).toHaveBeenCalledWith(
          expect.objectContaining({
            variables: {
              fullPath: namespace,
              startDate: expect.anything(),
              endDate: expect.anything(),
              includeIssues: true,
              includeMergeRequests: false,
              includeGroups: false,
              includeProjects: false,
              includePipelines: false,
              includeUsers: false,
            },
          }),
        );
      });

      it('does not call `setAlerts`', () => {
        expect(setAlerts).not.toHaveBeenCalled();
      });

      it('returns `-` when the metric is unknown', async () => {
        obj = await fetch({ ...defaultParams, query: { metric: 'fake_metric' } });

        expect(obj).toBe('-');
      });

      it('returns `0` when there is no data and background aggregation is enabled', async () => {
        obj = await fetch(defaultParams);

        expect(obj).toBe(0);
      });

      describe.each`
        description              | queryResponse                             | expectedValue
        ${'with data available'} | ${mockGroupUsageMetricsQueryResponse}     | ${123}
        ${'with zeroed data'}    | ${mockGroupUsageMetricsZeroQueryResponse} | ${0}
      `('$description', ({ queryResponse, expectedValue }) => {
        beforeEach(async () => {
          jest.spyOn(defaultClient, 'query').mockResolvedValue({ data: queryResponse });

          obj = await fetch({ ...defaultParams, setVisualizationOverrides });
        });

        it('returns the value as expected', () => {
          expect(obj).toBe(expectedValue);
        });

        it('sets the visualization tooltip and metric title icon', () => {
          expect(setVisualizationOverrides).toHaveBeenCalledWith({
            visualizationOptionOverrides: expect.objectContaining({
              titleIcon: 'work-item-issue',
              tooltip: {
                description:
                  'Usage data is a cumulative count and is updated monthly. Last updated: 2023-11-26 11:59 PM',
              },
            }),
          });
        });
      });

      describe('with data missing `recordedAt` timestamp', () => {
        beforeEach(async () => {
          jest
            .spyOn(defaultClient, 'query')
            .mockResolvedValue({ data: mockGroupUsageMetricsQueryResponse });

          await fetch({
            ...defaultParams,
            query: { metric: USAGE_OVERVIEW_IDENTIFIER_PIPELINES },
            setVisualizationOverrides,
          });
        });

        it('sets the correct visualization tooltip', () => {
          expect(setVisualizationOverrides).toHaveBeenCalledWith({
            visualizationOptionOverrides: expect.objectContaining({
              tooltip: {
                description: 'Usage data is a cumulative count and is updated monthly.',
              },
            }),
          });
        });
      });
    });

    describe('with visualizationOptions', () => {
      const visualizationOptions = { unit: 'percent', decimalPlaces: 1 };

      beforeEach(async () => {
        jest
          .spyOn(defaultClient, 'query')
          .mockResolvedValue({ data: mockGroupUsageMetricsQueryResponse });

        obj = await fetch({
          ...defaultParams,
          setVisualizationOverrides,
          visualizationOptions,
        });
      });

      it('passes visualization options to visualization', () => {
        expect(setVisualizationOverrides).toHaveBeenCalledWith({
          visualizationOptionOverrides: expect.objectContaining({
            tooltip: {
              description:
                'Usage data is a cumulative count and is updated monthly. Last updated: 2023-11-26 11:59 PM',
            },
            ...visualizationOptions,
          }),
        });
      });
    });

    describe('for project namespaces', () => {
      describe.each(USAGE_OVERVIEW_GROUP_ONLY_IDENTIFIERS)(
        '`%s` metric data is requested',
        (metric) => {
          beforeEach(async () => {
            jest.spyOn(defaultClient, 'query').mockResolvedValueOnce({
              data: { project: { name: 'some-namespace' }, group: null },
            });
            obj = await fetch({
              ...defaultParams,
              query: { metric },
            });
          });

          it('calls `setAlert` with correct error message', () => {
            expect(setAlerts).toHaveBeenCalledWith({
              title: 'Failed to load dashboard panel.',
              errors: expect.arrayContaining([
                'This visualization is not supported for project namespaces.',
              ]),
              canRetry: false,
            });
          });

          it('returns `undefined`', () => {
            expect(obj).toBeUndefined();
          });
        },
      );
    });

    describe('with `overviewCountsAggregationEnabled=false`', () => {
      describe.each`
        description               | queryResponse                             | expectedValue
        ${'with valid response'}  | ${mockGroupUsageMetricsQueryResponse}     | ${123}
        ${'with zeroes response'} | ${mockGroupUsageMetricsZeroQueryResponse} | ${'-'}
        ${'with no data'}         | ${{}}                                     | ${'-'}
      `('$description', ({ queryResponse, expectedValue }) => {
        beforeEach(async () => {
          jest.spyOn(defaultClient, 'query').mockResolvedValue({ data: queryResponse });

          obj = await fetch({
            ...defaultParams,
            overviewCountsAggregationEnabled: false,
          });
        });

        it('returns the value as expected', () => {
          expect(obj).toBe(expectedValue);
        });

        it('calls `setAlert` with correct error message', () => {
          expect(setAlerts).toHaveBeenCalledWith({
            canRetry: false,
            description: 'No data available',
            title: 'Background aggregation not enabled',
            warnings: [
              {
                description:
                  'To see usage overview, you must %{linkStart}enable background aggregation%{linkEnd}.',
                link: '/help/user/analytics/value_streams_dashboard.html#enable-or-disable-overview-background-aggregation',
              },
            ],
          });
        });
      });
    });
  });
});
