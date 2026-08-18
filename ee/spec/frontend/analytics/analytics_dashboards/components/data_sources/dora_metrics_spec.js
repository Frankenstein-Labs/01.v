import { mockDoraMetricsResponseData } from 'jest/analytics/shared/mock_data';
import fetch, {
  seriesToMedianSeries,
  seriesToAverageSeries,
} from 'ee/analytics/analytics_dashboards/data_sources/dora_metrics';
import { DORA_METRICS_CHARTS_ADDITIONAL_OPTS } from 'ee/analytics/analytics_dashboards/constants';
import { defaultClient } from 'ee/analytics/analytics_dashboards/graphql/client';
import {
  DATE_RANGE_OPTION_LAST_180_DAYS,
  DATE_RANGE_OPTION_LAST_7_DAYS,
} from 'ee/analytics/analytics_dashboards/components/filters/constants';
import {
  BUCKETING_INTERVAL_DAILY,
  BUCKETING_INTERVAL_MONTHLY,
} from '~/analytics/shared/graphql/constants';
import { dataSeries, medianSeries, nullSeries } from '../../mock_data';

describe('Dora Metrics Data Source', () => {
  let res;
  let mockSetVisualizationOverrides;

  const query = { metric: 'lead_time_for_changes', dateRange: DATE_RANGE_OPTION_LAST_180_DAYS };
  const subtitle = 'Last 180 days';
  const title = 'Dora Metrics Chart';
  const namespace = 'cool namespace';
  const defaultParams = {
    title,
    namespace,
    query,
  };

  const mockResolvedQuery = (dora = mockDoraMetricsResponseData) =>
    jest.spyOn(defaultClient, 'query').mockResolvedValueOnce({ data: { group: { dora } } });

  const expectQueryWithVariables = (variables) =>
    expect(defaultClient.query).toHaveBeenCalledWith(
      expect.objectContaining({
        variables: expect.objectContaining(variables),
      }),
    );

  beforeEach(() => {
    mockSetVisualizationOverrides = jest.fn();
  });

  describe('fetch', () => {
    describe('default', () => {
      describe('with data available', () => {
        beforeEach(async () => {
          mockResolvedQuery();

          res = await fetch({
            namespace,
            query,
            setVisualizationOverrides: mockSetVisualizationOverrides,
          });
        });

        it('returns a single value', () => {
          expect(res).toBe('0.2721');
        });

        it('correctly applies query parameters', () => {
          expectQueryWithVariables({
            startDate: new Date('2020-01-08'),
            endDate: new Date('2020-07-06'),
            fullPath: 'cool namespace',
            interval: 'ALL',
          });
        });

        it('sets the visualization title and icon', () => {
          expect(mockSetVisualizationOverrides).toHaveBeenCalledWith({
            visualizationOptionOverrides: { subtitle },
          });
        });
      });

      describe('with no data available', () => {
        it('returns a `-`', async () => {
          mockResolvedQuery({ metrics: [] });
          res = await fetch({ namespace, query });

          expect(res).toBe('-');
        });
      });

      describe('with an unsupported date range', () => {
        beforeEach(() => {
          mockResolvedQuery();
        });

        it('calls setVisualizationOverrides with 180 days', async () => {
          await fetch({
            namespace,
            query: {
              ...query,
              dateRange: '7_5_days',
            },
            setVisualizationOverrides: mockSetVisualizationOverrides,
          });

          expect(mockSetVisualizationOverrides).toHaveBeenCalledWith({
            visualizationOptionOverrides: { subtitle },
          });
        });
      });
    });

    describe('query overrides', () => {
      it('can override the date range', async () => {
        mockResolvedQuery();
        res = await fetch({
          ...defaultParams,
          query: {
            ...query,
            dateRange: DATE_RANGE_OPTION_LAST_7_DAYS,
          },
        });

        expectQueryWithVariables({
          startDate: new Date('2020-06-29'),
          endDate: new Date('2020-07-06'),
          fullPath: 'cool namespace',
          interval: 'ALL',
        });
      });

      it('can override the namespace', async () => {
        mockResolvedQuery();
        res = await fetch({
          ...defaultParams,
          query: {
            ...query,
            namespace: 'cool-namespace/sub-namespace',
          },
        });

        expectQueryWithVariables({
          startDate: new Date('2020-01-08'),
          endDate: new Date('2020-07-06'),
          fullPath: 'cool-namespace/sub-namespace',
          interval: 'ALL',
        });
      });
    });

    describe('with interval=ALL', () => {
      beforeEach(async () => {
        mockResolvedQuery();
        res = await fetch({
          namespace,
          query,
          setVisualizationOverrides: mockSetVisualizationOverrides,
        });
      });

      it('returns a single value', () => {
        expect(res).toBe('0.2721');
      });

      it('sets the title and titleIcon options', () => {
        expect(mockSetVisualizationOverrides).toHaveBeenCalledWith({
          visualizationOptionOverrides: { subtitle },
        });
      });
    });

    const timeSeriesData = [dataSeries, medianSeries, nullSeries];

    describe.each`
      interval
      ${BUCKETING_INTERVAL_DAILY}
      ${BUCKETING_INTERVAL_MONTHLY}
    `('with interval=$interval', ({ interval }) => {
      beforeEach(async () => {
        mockResolvedQuery();
        res = await fetch({
          namespace,
          query: {
            ...query,
            interval,
          },
          setVisualizationOverrides: mockSetVisualizationOverrides,
        });
      });

      it('returns a time series', () => {
        expect(res).toEqual(timeSeriesData);
      });

      it('returns the data, median and null series', () => {
        expect(timeSeriesData.map(({ name }) => name)).toEqual([
          'Lead time for changes',
          'Median (last 180d)',
          'No merge requests were deployed during this period',
        ]);
      });

      it('calls setVisualizationOverrides', () => {
        expect(mockSetVisualizationOverrides).toHaveBeenCalledWith({
          visualizationOptionOverrides: {
            subtitle: 'Last 180 days',
            ...DORA_METRICS_CHARTS_ADDITIONAL_OPTS[query.metric],
          },
        });
      });

      describe('no data available', () => {
        beforeEach(async () => {
          mockResolvedQuery({ metrics: [] });
          res = await fetch({
            namespace,
            query: {
              ...query,
              interval,
            },
            setVisualizationOverrides: mockSetVisualizationOverrides,
          });
        });

        it('returns an empty array', () => {
          expect(res).toEqual([]);
        });
      });
    });
  });

  describe('seriesToAverageSeries', () => {
    const seriesName = 'Average';

    it('returns an empty object if chart data is undefined', () => {
      const data = seriesToAverageSeries(undefined, seriesName);

      expect(data).toStrictEqual({});
    });

    it('returns an empty object if chart data is blank', () => {
      const data = seriesToAverageSeries(null, seriesName);

      expect(data).toStrictEqual({});
    });

    it('returns the correct average values', () => {
      const data = seriesToAverageSeries(
        [
          ['Jul 01, 2015', 2],
          ['Jul 02, 2015', 3],
          ['Jul 03, 2015', 4],
        ],
        seriesName,
      );

      expect(data).toStrictEqual({
        name: seriesName,
        data: [
          ['Jul 01, 2015', 3],
          ['Jul 02, 2015', 3],
          ['Jul 03, 2015', 3],
        ],
      });
    });
  });

  describe('seriesToMedianSeries', () => {
    const seriesName = 'Median';

    it('returns an empty object if chart data is undefined', () => {
      const data = seriesToMedianSeries(undefined, seriesName);

      expect(data).toStrictEqual({});
    });

    it('returns an empty object if chart data is blank', () => {
      const data = seriesToMedianSeries(null, seriesName);

      expect(data).toStrictEqual({});
    });

    it('returns the correct median values', () => {
      const data = seriesToMedianSeries(
        [
          ['Jul 01, 2015', 1],
          ['Jul 02, 2015', 3],
          ['Jul 03, 2015', 10],
        ],
        seriesName,
      );

      expect(data).toStrictEqual({
        name: seriesName,
        data: [
          ['Jul 01, 2015', 3],
          ['Jul 02, 2015', 3],
          ['Jul 03, 2015', 3],
        ],
      });
    });
  });
});
