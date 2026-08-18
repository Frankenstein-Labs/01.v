import { getDayDifference, newDate } from '~/lib/utils/datetime_utility';
import { median } from '~/lib/utils/number_utils';
import { __, sprintf } from '~/locale';
import {
  BUCKETING_INTERVAL_ALL,
  BUCKETING_INTERVAL_MONTHLY,
  BUCKETING_INTERVAL_DAILY,
} from '~/analytics/shared/graphql/constants';
import DoraMetricsQuery from '~/analytics/shared/graphql/dora_metrics.query.graphql';
import { extractQueryResponseFromNamespace, scaledValueForDisplay } from '~/analytics/shared/utils';
import {
  VALUE_STREAM_METRIC_TILE_METADATA,
  DORA_METRICS_NULL_SERIES_TITLE,
  DORA_METRICS_SECONDARY_SERIES_NAME,
  DORA_METRICS,
} from '~/analytics/shared/constants';
import { TABLE_METRICS } from 'ee/analytics/dashboards/constants';
import { DORA_METRICS_CHARTS_ADDITIONAL_OPTS } from 'ee/analytics/analytics_dashboards/constants';
import { DATE_RANGE_OPTION_LAST_180_DAYS } from 'ee/analytics/analytics_dashboards/components/filters/constants';
import { getDateRange } from '~/explore/analytics_dashboards/components/utils';
import { buildNullSeries } from 'ee/analytics/shared/utils';
import { DEFAULT_NULL_SERIES_OPTIONS, NULL_SERIES_ID } from 'ee/analytics/shared/constants';
import { defaultClient } from '../graphql/client';

const lineChartAdditionalSeriesOptions = {
  areaStyle: {
    opacity: 0,
  },
  showSymbol: false,
};

/**
 * Converts a data series into a formatted average series
 *
 * @param {Array} chartSeriesData Correctly formatted chart series data
 *
 * @returns {Object} An object containing the series name and an array of original data keys with the average of the dataset as each value.
 */
export const seriesToAverageSeries = (chartSeriesData, seriesName) => {
  if (!chartSeriesData || !chartSeriesData.length) return {};

  const average =
    Math.round(
      (chartSeriesData.reduce((acc, day) => acc + day[1], 0) / chartSeriesData.length) * 10,
    ) / 10;

  return {
    name: seriesName,
    data: chartSeriesData.map((day) => [day[0], average]),
  };
};

/**
 * Converts a data series into a formatted median series
 *
 * @param {Array} chartSeriesData Correctly formatted chart series data
 *
 * @returns {Object} An object containing the series name and an array of original data keys with the median of the dataset as each value.
 */
export const seriesToMedianSeries = (chartSeriesData, seriesName) => {
  if (!chartSeriesData) return {};

  const medianValue = median(chartSeriesData.filter((day) => day[1] !== null).map((day) => day[1]));

  return {
    name: seriesName,
    data: chartSeriesData.map((day) => [day[0], medianValue]),
  };
};

const asValue = ({ metrics, targetMetric, units }) => {
  if (!metrics.length) return '-';

  const metricValue = metrics[0][targetMetric] || 0;
  return scaledValueForDisplay(metricValue, units);
};

const calculateAdditionalSeries = ({ targetMetric, rawData, daysCount }) => {
  const seriesName = DORA_METRICS_SECONDARY_SERIES_NAME[targetMetric];
  const formatSeries =
    targetMetric === DORA_METRICS.DEPLOYMENT_FREQUENCY
      ? seriesToAverageSeries
      : seriesToMedianSeries;

  return {
    ...lineChartAdditionalSeriesOptions,
    ...formatSeries(rawData, sprintf(seriesName, { days: daysCount })),
  };
};

const asTimeSeries = ({ metrics, targetMetric, daysCount, nullSeriesTitle = __('No data') }) => {
  // Extracts a date + value, returns an array of arrays [[date, value],[date, value]]
  // Calculates a "null" series and returns all the series in the correct order for rendering
  const rawData = metrics.map(({ date, ...rest }) => {
    const formattedDate = newDate(date);
    return [formattedDate, rest[targetMetric]];
  });

  if (!rawData.some(([, value]) => Boolean(value))) return [];

  const data = { name: VALUE_STREAM_METRIC_TILE_METADATA[targetMetric].label, data: rawData };
  const [nullSeries, primarySeries] = buildNullSeries({
    seriesData: [data],
    nullSeriesTitle,
    nullSeriesOptions: { ...DEFAULT_NULL_SERIES_OPTIONS, id: NULL_SERIES_ID },
  });
  const additionalSeries = calculateAdditionalSeries({ targetMetric, rawData, daysCount });

  return [primarySeries, additionalSeries, nullSeries].map(
    ({ data: seriesData, ...seriesRest }) => ({
      data: seriesData.filter(([, n]) => !Number.isNaN(n)),
      ...seriesRest,
    }),
  );
};

const fetchDoraMetricsQuery = async ({ metric, namespace, startDate, endDate, interval }) => {
  const result = await defaultClient.query({
    query: DoraMetricsQuery,
    variables: {
      fullPath: namespace,
      interval,
      startDate,
      endDate,
    },
  });

  const { metrics } = extractQueryResponseFromNamespace({ result, resultKey: 'dora' });
  const { units } = TABLE_METRICS[metric];
  const daysCount = getDayDifference(startDate, endDate);

  if ([BUCKETING_INTERVAL_DAILY, BUCKETING_INTERVAL_MONTHLY].includes(interval)) {
    return asTimeSeries({
      metrics,
      targetMetric: metric,
      nullSeriesTitle: DORA_METRICS_NULL_SERIES_TITLE[metric] ?? null,
      daysCount,
    });
  }

  return asValue({ metrics, targetMetric: metric, units });
};

export default async function fetch({
  namespace,
  query: {
    metric,
    dateRange: defaultDateRange,
    interval = BUCKETING_INTERVAL_ALL,
    ...overridesRest
  } = {},
  filters: {
    dateRangeOption,
    startDate: filtersStartDate = null,
    endDate: filtersEndDate = null,
  } = {},
  setVisualizationOverrides = () => {},
}) {
  const {
    startDate,
    endDate,
    text: subtitle,
  } = getDateRange(dateRangeOption || defaultDateRange, DATE_RANGE_OPTION_LAST_180_DAYS);

  setVisualizationOverrides({
    visualizationOptionOverrides: {
      subtitle,
      ...(interval !== BUCKETING_INTERVAL_ALL && DORA_METRICS_CHARTS_ADDITIONAL_OPTS[metric]),
    },
  });

  return fetchDoraMetricsQuery({
    startDate: filtersStartDate ?? startDate,
    endDate: filtersEndDate ?? endDate,
    metric,
    namespace,
    interval,
    ...overridesRest,
  });
}
