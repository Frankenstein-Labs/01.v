import AiAgentPlatformFlowsUsageByUserQuery from '~/analytics/dashboards/ai_impact/graphql/ai_agent_platform_flows_usage_by_user.query.graphql';
import { DATE_RANGE_OPTION_LAST_30_DAYS } from 'ee/analytics/analytics_dashboards/components/filters/constants';
import { getDateRange } from '~/explore/analytics_dashboards/components/utils';
import { extractQueryResponseFromNamespace } from '~/analytics/shared/utils';
import { toISODateFormat } from '~/lib/utils/datetime_utility';
import { defaultClient } from '../graphql/client';

const DEFAULT_PAGE_SIZE = 10;

const requestFlowsUsageByUser = async ({ namespace, startDate, endDate, pagination }) => {
  const result = await defaultClient.query({
    query: AiAgentPlatformFlowsUsageByUserQuery,
    variables: {
      fullPath: namespace,
      startDate,
      endDate,
      first: pagination.first,
      last: pagination.last,
      before: pagination.startCursor,
      after: pagination.endCursor,
    },
  });

  const { agentPlatform: { userFlowCounts: { nodes, pageInfo } = {} } = {} } =
    extractQueryResponseFromNamespace({
      result,
      resultKey: 'aiMetrics',
    });

  if (!nodes?.length) return {};

  return {
    nodes,
    pageInfo: {
      ...pagination,
      ...pageInfo,
    },
  };
};

export default async function fetch({
  namespace,
  query: { dateRange, pagination = { first: DEFAULT_PAGE_SIZE } } = {},
  setVisualizationOverrides = () => {},
}) {
  // Default to 30 days if an invalid date range is given
  const {
    startDate,
    endDate,
    text: subtitle,
  } = getDateRange(dateRange, DATE_RANGE_OPTION_LAST_30_DAYS);

  setVisualizationOverrides({ visualizationOptionOverrides: { subtitle } });

  const data = await requestFlowsUsageByUser({
    startDate: toISODateFormat(startDate, true),
    endDate: toISODateFormat(endDate, true),
    namespace,
    pagination,
  });

  return data;
}
