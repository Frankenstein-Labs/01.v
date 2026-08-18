import {
  getAbsoluteDateRange,
  getTimeframe,
  createIssueUrlWithMetricDetails,
  viewTracesUrlWithMetric,
  isHistogram,
  metricHasRelatedTraces,
} from 'ee/metrics/details/utils';
import setWindowLocation from 'helpers/set_window_location_helper';
import { useFakeDate } from 'helpers/fake_date';
import { METRIC_TYPE } from 'ee/metrics//constants';
import {
  mockSumMetricWithNoTracesResponse,
  mockSumMetricWithTracesResponse,
  mockHistogramMetricWithNoTracesResponse,
  mockHistogramMetricWithTracesResponse,
} from '../mock_data';

describe('getAbsoluteDateRange', () => {
  useFakeDate('2024-08-01 11:00:00');

  it('returns the absolute date range for custom dates', () => {
    const dateRange = {
      value: 'custom',
      startDate: new Date('2023-01-01'),
      endDate: new Date('2023-01-31'),
    };

    expect(getAbsoluteDateRange(dateRange)).toStrictEqual({
      endDate: new Date('2023-01-31'),
      startDate: new Date('2023-01-01'),
      value: 'custom',
    });
  });

  it('returns the absolute date range for date periods', () => {
    const dateRange = { value: '5m' };

    expect(getAbsoluteDateRange(dateRange)).toStrictEqual({
      endDate: new Date('2024-08-01 11:00:00'),
      startDate: new Date('2024-08-01 10:55:00'),
      value: 'custom',
    });
  });
});

describe('getTimeframe', () => {
  it('returns the timeframe array', () => {
    const dateRange = {
      value: 'custom',
      startDate: new Date('2023-01-01'),
      endDate: new Date('2023-01-31'),
    };

    expect(getTimeframe(dateRange)).toStrictEqual([
      'Sun, 01 Jan 2023 00:00:00 GMT',
      'Tue, 31 Jan 2023 00:00:00 GMT',
    ]);
  });
});

describe('createIssueUrlWithMetricDetails', () => {
  useFakeDate('2024-08-01 11:00:00');

  const metricName = 'Test Metric';
  const metricType = 'Sum';
  const createIssueUrl = 'https://example.com/issues/new';
  const imageSnapshotUrl = 'https://example.com/image.png';
  const filters = {
    dateRange: {
      value: '5m',
    },
    groupBy: {
      func: 'sum',
    },
  };

  beforeEach(() => {
    setWindowLocation(
      'http://gdk.test:3443/flightjs/Flight/-/metrics/app.ads.ad_requests?type=Sum&date_range=5m',
    );
  });

  it('returns a URL with the metric details', () => {
    const metricsDetails = {
      fullUrl:
        'http://gdk.test:3443/flightjs/Flight/-/metrics/app.ads.ad_requests?type=Sum&date_range=custom&group_by_fn=sum&date_start=2024-08-01T10%3A55%3A00.000Z&date_end=2024-08-01T11%3A00%3A00.000Z',
      name: metricName,
      type: metricType,
      timeframe: ['Thu, 01 Aug 2024 10:55:00 GMT', 'Thu, 01 Aug 2024 11:00:00 GMT'],
      imageSnapshotUrl,
    };
    const expectedUrl = `https://example.com/issues/new?observability_metric_details=${encodeURIComponent(JSON.stringify(metricsDetails))}&${encodeURIComponent('issue[confidential]')}=true`;

    expect(
      createIssueUrlWithMetricDetails({
        metricName,
        metricType,
        filters,
        createIssueUrl,
        imageSnapshotUrl,
      }),
    ).toBe(expectedUrl);
  });

  it('handles custom date range', () => {
    const customDateRange = {
      value: 'custom',
      startDate: new Date('2023-01-01'),
      endDate: new Date('2023-01-31'),
    };

    const expectedUrl = `https://example.com/issues/new?observability_metric_details=${encodeURIComponent(
      JSON.stringify({
        fullUrl:
          'http://gdk.test:3443/flightjs/Flight/-/metrics/app.ads.ad_requests?type=Sum&date_range=custom&date_start=2023-01-01T00%3A00%3A00.000Z&date_end=2023-01-31T00%3A00%3A00.000Z',
        name: metricName,
        type: metricType,
        timeframe: ['Sun, 01 Jan 2023 00:00:00 GMT', 'Tue, 31 Jan 2023 00:00:00 GMT'],
      }),
    )}&${encodeURIComponent('issue[confidential]')}=true`;

    expect(
      createIssueUrlWithMetricDetails({
        metricName,
        metricType,
        filters: { dateRange: customDateRange },
        createIssueUrl,
      }),
    ).toBe(expectedUrl);
  });
});

describe('viewTracesUrlWithMetric', () => {
  it('returns the traces index URL with trace-ids filtering and date_range = timestamp +- 6h', () => {
    expect(
      viewTracesUrlWithMetric('https://example.com/traces/index', {
        traceIds: ['test-1', 'test-2'],
        timestamp: new Date('2024-08-01 11:00:00').getTime(),
      }),
    ).toBe(
      'https://example.com/traces/index?trace_id[]=test-1&trace_id[]=test-2&date_range=custom&date_start=2024-08-01T05:00:00.000Z&date_end=2024-08-01T17:00:00.000Z',
    );
  });

  it('handles missing timestamp', () => {
    expect(
      viewTracesUrlWithMetric('https://example.com/traces/index', {
        traceIds: ['test-1', 'test-2'],
      }),
    ).toBe('https://example.com/traces/index?trace_id[]=test-1&trace_id[]=test-2&date_range=1h');
  });

  it('handles invalid timestamp', () => {
    expect(
      viewTracesUrlWithMetric('https://example.com/traces/index', {
        traceIds: ['test-1', 'test-2'],
        timestamp: '1234',
      }),
    ).toBe('https://example.com/traces/index?trace_id[]=test-1&trace_id[]=test-2&date_range=1h');
  });
});

describe('isHistogram', () => {
  it.each`
    metricType                | expected
    ${'Histogram'}            | ${true}
    ${'ExponentialHistogram'} | ${true}
    ${'Sum'}                  | ${false}
    ${'Gauge'}                | ${false}
  `('returns $expected when metric type is $metricType', ({ metricType, expected }) => {
    expect(isHistogram(metricType)).toBe(expected);
  });
});

describe('metricHasRelatedTraces', () => {
  it('returns true if non-histogram metric has traces', () => {
    expect(metricHasRelatedTraces(mockSumMetricWithTracesResponse.results, METRIC_TYPE.Sum)).toBe(
      true,
    );
  });

  it('returns false if non-histogram metric data has no traces', () => {
    expect(metricHasRelatedTraces(mockSumMetricWithNoTracesResponse.results, METRIC_TYPE.Sum)).toBe(
      false,
    );
  });

  it('returns true if histogram metric has traces', () => {
    expect(
      metricHasRelatedTraces(mockHistogramMetricWithTracesResponse.results, METRIC_TYPE.Histogram),
    ).toBe(true);
  });

  it('returns false if histogram metric data has no traces', () => {
    expect(
      metricHasRelatedTraces(
        mockHistogramMetricWithNoTracesResponse.results,
        METRIC_TYPE.Histogram,
      ),
    ).toBe(false);
  });
});
