import AiMetricsQuery from '~/analytics/dashboards/ai_impact/graphql/ai_metrics.query.graphql';
import { DATE_RANGE_OPTION_LAST_180_DAYS } from 'ee/analytics/analytics_dashboards/components/filters/constants';
import { getDateRange } from '~/explore/analytics_dashboards/components/utils';
import { defaultClient } from 'ee/analytics/analytics_dashboards/graphql/client';
import { extractQueryResponseFromNamespace } from '~/analytics/shared/utils';
import { s__ } from '~/locale';
import { getMonthsInDateRange } from 'ee/analytics/dashboards/utils';
import { helpPagePath } from '~/helpers/help_page_helper';

const extractLinesOfCodeMetrics = (result) => {
  const { codeSuggestions } = extractQueryResponseFromNamespace({
    result,
    resultKey: 'aiMetrics',
  });

  const { acceptedLinesOfCode, shownLinesOfCode } = codeSuggestions ?? {};

  return {
    acceptedLinesOfCode,
    shownLinesOfCode,
  };
};

const codeSuggestionsLinesOfCodeQuery = async ({ namespace, startDate, endDate, monthLabel }) => {
  const result = await defaultClient.query({
    query: AiMetricsQuery,
    variables: {
      fullPath: namespace,
      startDate,
      endDate,
    },
  });

  return { monthLabel, data: extractLinesOfCodeMetrics(result) };
};

const formatChartData = (result = []) => {
  // To prevent gaps in the chart, return zeroes rather than nullish values
  const formatDataPoint = (monthLabel, value) => [monthLabel, value ?? 0];

  const acceptedLinesOfCodeData = result.map(({ monthLabel, data: { acceptedLinesOfCode } }) =>
    formatDataPoint(monthLabel, acceptedLinesOfCode),
  );

  const shownLinesOfCodeData = result.map(({ monthLabel, data: { shownLinesOfCode } }) =>
    formatDataPoint(monthLabel, shownLinesOfCode),
  );

  return [
    {
      name: s__('CodeGenerationVolumeTrendsChart|Lines of code accepted'),
      data: acceptedLinesOfCodeData,
    },
    {
      name: s__('CodeGenerationVolumeTrendsChart|Lines of code shown'),
      data: shownLinesOfCodeData,
    },
  ];
};

const fetchCodeSuggestionsLinesOfCodeData = async ({ namespace, startDate, endDate }) => {
  const monthsData = getMonthsInDateRange(startDate, endDate);
  const promises = monthsData.map(({ monthLabel, fromDate, toDate }) =>
    codeSuggestionsLinesOfCodeQuery({
      namespace,
      startDate: fromDate,
      endDate: toDate,
      monthLabel,
    }),
  );

  const result = await Promise.all(promises);

  return formatChartData(result);
};

const hasChartData = (chartData = []) =>
  chartData.some(({ data }) => data.some(([, value]) => value));

export default async function fetch({
  namespace,
  query: { dateRange, namespace: namespaceOverride } = {},
  setVisualizationOverrides = () => {},
}) {
  // Default to 180 days if an invalid date range is given
  const {
    startDate,
    endDate,
    text: subtitle,
  } = getDateRange(dateRange, DATE_RANGE_OPTION_LAST_180_DAYS);

  const visualizationOptionOverrides = {
    subtitle,
    tooltip: {
      description: s__(
        'CodeGenerationVolumeTrendsChart|Tracks lines of code accepted and shown from GitLab Duo Code Suggestions. %{linkStart}Learn more%{linkEnd}.',
      ),
      descriptionLink: helpPagePath('user/analytics/duo_and_sdlc_trends', {
        anchor: 'code-generation-volume-trends',
      }),
    },
  };

  setVisualizationOverrides({ visualizationOptionOverrides });

  const chartData = await fetchCodeSuggestionsLinesOfCodeData({
    namespace: namespaceOverride ?? namespace,
    startDate,
    endDate,
  });

  if (!hasChartData(chartData)) return [];

  return chartData;
}
