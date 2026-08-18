import { s__ } from '~/locale';
import FinishedPipelinesUsingDapQuery from '~/analytics/dashboards/ai_impact/graphql/finished_pipelines_using_dap.query.graphql';
import { defaultClient } from 'ee/analytics/analytics_dashboards/graphql/client';
import { toISODateFormat, formatIso8601Date } from '~/lib/utils/datetime/date_format_utility';
import { getDateRange } from '~/explore/analytics_dashboards/components/utils';
import { DATE_RANGE_OPTION_LAST_180_DAYS } from 'ee/analytics/analytics_dashboards/components/filters/constants';
import { extractQueryResponseFromNamespace } from '~/analytics/shared/utils';
import { localeDateFormat } from '~/lib/utils/datetime/locale_dateformat';
import { newDate, getMonthsBetweenDates } from '~/lib/utils/datetime/date_calculation_utility';
import { helpPagePath } from '~/helpers/help_page_helper';

// The backend only returns months with data; gaps are filled with 0 to ensure a continuous series.
const buildChartSeries = ({ nodes, countKey, startDate, endDate }) => {
  const countsByISODate = new Map(nodes.map((node) => [node.dimensions.startedAt, node[countKey]]));

  return getMonthsBetweenDates(startDate, endDate, { utc: true }).map(({ month, year }) => {
    // Keys are always first-of-month ISO dates matching the backend's monthly aggregation buckets.
    const isoDateKey = formatIso8601Date(year, month, 1);
    return [
      localeDateFormat.asMonthYear.format(newDate(isoDateKey)),
      countsByISODate.get(isoDateKey) ?? 0,
    ];
  });
};

const fetchMetrics = async ({ namespace, startDate, endDate }) => {
  const result = await defaultClient.query({
    query: FinishedPipelinesUsingDapQuery,
    variables: {
      fullPath: namespace,
      startDate: toISODateFormat(startDate, true),
      endDate: toISODateFormat(endDate, true),
    },
  });

  return extractQueryResponseFromNamespace({ result, resultKey: 'analytics' });
};

const fetchPipelinesData = async ({ namespace, startDate, endDate }) => {
  const { pipelines } = await fetchMetrics({ namespace, startDate, endDate });

  const nodes = pipelines?.aggregated?.nodes;

  if (!nodes?.length) return [];

  return [
    {
      name: s__('PipelinesUsingDapChart|With Agent Platform'),
      data: buildChartSeries({ nodes, countKey: 'duoPipelinesCount', startDate, endDate }),
    },
    {
      name: s__('PipelinesUsingDapChart|All Pipelines'),
      data: buildChartSeries({ nodes, countKey: 'allPipelinesCount', startDate, endDate }),
    },
  ];
};

export default async function fetch({
  namespace,
  query: { dateRange } = {},
  setVisualizationOverrides = () => {},
}) {
  const {
    startDate,
    endDate,
    text: subtitle,
  } = getDateRange(dateRange, DATE_RANGE_OPTION_LAST_180_DAYS);

  setVisualizationOverrides({
    visualizationOptionOverrides: {
      subtitle,
      tooltip: {
        description: s__(
          'PipelinesUsingDapChart|Tracks pipelines triggered by GitLab Duo Agent Platform compared to all pipelines. %{linkStart}Learn more%{linkEnd}.',
        ),
        descriptionLink: helpPagePath('user/analytics/duo_and_sdlc_trends', {
          anchor: 'pipelines-using-gitlab-duo-agent-platform',
        }),
      },
    },
  });

  return fetchPipelinesData({ namespace, startDate, endDate });
}
