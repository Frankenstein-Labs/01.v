import { truncate } from 'lodash-es';
import { toISODateFormat } from '~/lib/utils/datetime_utility';
import { s__, __ } from '~/locale';
import { DATE_RANGE_OPTION_LAST_30_DAYS } from 'ee/analytics/analytics_dashboards/components/filters/constants';
import { getDateRange } from '~/explore/analytics_dashboards/components/utils';
import { extractQueryResponseFromNamespace } from '~/analytics/shared/utils';
import CodeSuggestionsAcceptanceByIdeQuery from '~/analytics/dashboards/ai_impact/graphql/code_suggestions_acceptance_by_ide.query.graphql';
import { helpPagePath } from '~/helpers/help_page_helper';
import { defaultClient } from '../graphql/client';

const extractAcceptanceMetricsByIde = (nodes = []) =>
  nodes.reduce(
    (acc, { dimensions: { ideName } = {}, acceptedCount, shownCount, acceptanceRate }) => {
      if (!ideName || acceptanceRate === null) return acc;

      acc.chartData.push([acceptedCount, ideName]);
      acc.contextualData[ideName] = { acceptanceRate, shownCount };

      return acc;
    },
    { chartData: [], contextualData: {} },
  );

const fetchAcceptanceByIde = async ({ namespace, startDate, endDate }) => {
  const result = await defaultClient.query({
    query: CodeSuggestionsAcceptanceByIdeQuery,
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

  return extractAcceptanceMetricsByIde(duoCodeSuggestions?.aggregated?.nodes ?? []);
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
          'CodeSuggestionsAcceptanceByIdeChart|Shows accepted GitLab Duo Code Suggestions by IDE. %{linkStart}Learn more%{linkEnd}.',
        ),
        descriptionLink: helpPagePath('user/analytics/duo_and_sdlc_trends', {
          anchor: 'gitlab-duo-code-suggestions-acceptance-by-ide',
        }),
      },
      yAxis: {
        axisLabel: {
          formatter: (str) => truncate(str, { length: 9 }),
        },
      },
    },
  });

  const { chartData, contextualData } = await fetchAcceptanceByIde({
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
