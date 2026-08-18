import { CUSTOM_DATE_RANGE_OPTION } from '~/observability/constants';
import { periodToDateRange, createIssueUrlWithDetails } from '~/observability/utils';
import { mergeUrlParams, setUrlParams, getNormalizedURL } from '~/lib/utils/url_utility';
import { tracingListQueryFromAttributes } from 'ee/tracing/list/filter_bar/filters';
import { METRIC_TYPE } from '../constants';
import { filterObjToQuery } from './filters';

export function getAbsoluteDateRange(dateRange) {
  if (dateRange.value === CUSTOM_DATE_RANGE_OPTION) {
    return dateRange;
  }

  return periodToDateRange(dateRange.value);
}

export function getTimeframe(dateRange) {
  return [dateRange.startDate.toUTCString(), dateRange.endDate.toUTCString()];
}

export function createIssueUrlWithMetricDetails({
  metricName,
  metricType,
  filters,
  createIssueUrl,
  imageSnapshotUrl,
}) {
  const absoluteDateRange = getAbsoluteDateRange(filters.dateRange);

  const queryWithUpdatedDateRange = filterObjToQuery({
    ...filters,
    dateRange: absoluteDateRange,
  });

  const metricsDetails = {
    fullUrl: mergeUrlParams(queryWithUpdatedDateRange, window.location.href, {
      spreadArrays: true,
    }),
    name: metricName,
    type: metricType,
    timeframe: getTimeframe(absoluteDateRange),
    imageSnapshotUrl: imageSnapshotUrl || undefined,
  };

  return createIssueUrlWithDetails(createIssueUrl, metricsDetails, 'observability_metric_details');
}

export function viewTracesUrlWithMetric(tracingIndexUrl, { traceIds, timestamp }) {
  const INTERVAL_AROUND_TIMESTAMP = 6 * 60 * 60 * 1000; // 6hrs;
  return setUrlParams(
    tracingListQueryFromAttributes({
      traceIds,
      ...(Number.isFinite(timestamp)
        ? {
            startTimestamp: timestamp - INTERVAL_AROUND_TIMESTAMP,
            endTimestamp: timestamp + INTERVAL_AROUND_TIMESTAMP,
          }
        : {}),
    }),
    {
      url: getNormalizedURL(tracingIndexUrl),
      clearParams: true,
      railsArraySyntax: true,
      decodeParams: true,
    },
  );
}

export function isHistogram(metricType) {
  return [METRIC_TYPE.ExponentialHistogram, METRIC_TYPE.Histogram].includes(
    metricType.toLowerCase(),
  );
}

export function metricHasRelatedTraces(metricData = [], metricType) {
  // Check ee/spec/frontend/metrics/mock_data.js to see how metric data looks like
  if (isHistogram(metricType)) {
    const data = metricData[0]?.data?.[0] || {
      distribution: [],
      buckets: [],
    };
    return data.distribution.some((distribution) =>
      distribution.some(([, , relatedTraces]) => relatedTraces?.length > 0),
    );
  }
  return metricData.some((data) =>
    data.values?.some(([, , relatedTraces]) => relatedTraces?.length > 0),
  );
}
