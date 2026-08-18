import { toISODateFormat } from '~/lib/utils/datetime_utility';
import { __, s__ } from '~/locale';
import { DATE_RANGE_OPTION_LAST_30_DAYS } from 'ee/analytics/analytics_dashboards/components/filters/constants';
import { getDateRange } from '~/explore/analytics_dashboards/components/utils';
import { getLanguageDisplayName } from 'ee/analytics/analytics_dashboards/code_suggestions_languages';
import { truncate } from '~/lib/utils/text_utility';
import { calculateRate } from '~/analytics/dashboards/ai_impact/utils';
import { extractQueryResponseFromNamespace } from '~/analytics/shared/utils';
import CodeSuggestionsAcceptanceByLanguageQuery from '~/analytics/dashboards/ai_impact/graphql/code_suggestions_acceptance_by_language.query.graphql';
import { helpPagePath } from '~/helpers/help_page_helper';
import { defaultClient } from '../graphql/client';

// Variants like `js` and `javascript` map to one display name, so merge them
// client-side (the aggregation engine only groups by the raw `language` value).
const mergeMetricsByLanguage = (nodes = []) =>
  nodes.reduce(
    (
      acc,
      { dimensions: { language: languageId } = {}, acceptedCount, shownCount, acceptanceRate },
    ) => {
      const language = getLanguageDisplayName(languageId);

      if (!language || acceptanceRate === null) return acc;

      if (!acc[language]) {
        acc[language] = { acceptedCount: 0, shownCount: 0 };
      }

      acc[language].acceptedCount += acceptedCount;
      acc[language].shownCount += shownCount;

      return acc;
    },
    {},
  );

// Rates can't be merged, so recompute from the summed counts.
const calculateAcceptanceRates = (metricsByLanguage = {}) =>
  Object.entries(metricsByLanguage).reduce((acc, [language, metrics]) => {
    acc[language] = {
      ...metrics,
      acceptanceRate: calculateRate({
        numerator: metrics.acceptedCount,
        denominator: metrics.shownCount,
        asDecimal: true,
      }),
    };
    return acc;
  }, {});

// Merging re-sums counts, breaking the engine's ascending order.
const sortMetrics = (metricsWithRates) =>
  Object.entries(metricsWithRates).sort((a, b) => a[1].acceptedCount - b[1].acceptedCount);

const formatChartData = (sortedResults) => ({
  chartData: sortedResults.map(([language, { acceptedCount }]) => [acceptedCount, language]),
  contextualData: Object.fromEntries(
    sortedResults.map(([language, { acceptanceRate, shownCount }]) => [
      language,
      { acceptanceRate, shownCount },
    ]),
  ),
});

const extractAcceptanceMetricsByLanguage = (nodes = []) => {
  const mergedMetricsByLanguage = mergeMetricsByLanguage(nodes);
  const metricsWithRates = calculateAcceptanceRates(mergedMetricsByLanguage);
  const sortedResults = sortMetrics(metricsWithRates);

  return formatChartData(sortedResults);
};

const fetchAcceptanceByLanguage = async ({ namespace, startDate, endDate }) => {
  const result = await defaultClient.query({
    query: CodeSuggestionsAcceptanceByLanguageQuery,
    variables: {
      fullPath: namespace,
      startDate: toISODateFormat(startDate, true),
      endDate: toISODateFormat(endDate, true),
    },
  });

  const { duoCodeSuggestions } = extractQueryResponseFromNamespace({
    result,
    resultKey: 'analytics',
  });

  return extractAcceptanceMetricsByLanguage(duoCodeSuggestions?.aggregated?.nodes ?? []);
};

export default async function fetch({
  namespace,
  query: { dateRange, namespace: namespaceOverride } = {},
  setVisualizationOverrides = () => {},
}) {
  const {
    startDate,
    endDate,
    text: subtitle,
  } = getDateRange(dateRange, DATE_RANGE_OPTION_LAST_30_DAYS);

  setVisualizationOverrides({
    visualizationOptionOverrides: {
      subtitle,
      tooltip: {
        description: s__(
          'CodeSuggestionsAcceptanceByLanguageChart|Accepted GitLab Duo Code Suggestions by programming language. %{linkStart}Learn more%{linkEnd}.',
        ),
        descriptionLink: helpPagePath('user/analytics/duo_and_sdlc_trends', {
          anchor: 'gitlab-duo-code-suggestions-acceptance-by-language',
        }),
      },
      yAxis: {
        axisLabel: {
          formatter: (str) => truncate(str, 10),
        },
      },
    },
  });

  const { chartData, contextualData } = await fetchAcceptanceByLanguage({
    namespace: namespaceOverride ?? namespace,
    startDate,
    endDate,
  });

  if (!chartData.some(([value]) => value)) return {};

  return {
    [__('Suggestions accepted')]: chartData,
    contextualData,
  };
}
