import { isNil } from 'lodash-es';
import { formatNumber, s__, sprintf } from '~/locale';
import DuoUsedCountQuery from '~/analytics/dashboards/ai_impact/graphql/duo_used_count.query.graphql';
import DuoAgentPlatformChatsQuery from '~/analytics/dashboards/ai_impact/graphql/duo_agent_platform_chats.query.graphql';
import DuoAgentPlatformAgentFlowsUsersCountQuery from '~/analytics/dashboards/ai_impact/graphql/duo_agent_platform_agent_flows_users_count.query.graphql';
import DuoPowerUsersCountQuery from '~/analytics/dashboards/ai_impact/graphql/duo_power_users_count.query.graphql';
import DuoPipelinesRateQuery from '~/analytics/dashboards/ai_impact/graphql/duo_pipelines_rate.query.graphql';
import {
  AI_IMPACT_OVER_TIME_METRICS,
  AI_IMPACT_OVER_TIME_METRICS_TOOLTIPS,
} from 'ee/analytics/dashboards/ai_impact/constants';
import { DATE_RANGE_OPTION_LAST_30_DAYS } from 'ee/analytics/analytics_dashboards/components/filters/constants';
import { getDateRange } from '~/explore/analytics_dashboards/components/utils';
import { toISODateFormat } from '~/lib/utils/datetime_utility';
import { AI_METRICS, UNITS } from '~/analytics/shared/constants';
import { extractQueryResponseFromNamespace, scaledValueForDisplay } from '~/analytics/shared/utils';
import { extractAiMetricsResponse } from 'ee/analytics/dashboards/ai_impact/api';
import {
  calculateChange,
  calculateRate,
  getBadgeTrendIndicator,
} from 'ee/analytics/dashboards/ai_impact/utils';
import { defaultClient } from '../graphql/client';

const METRIC_QUERIES = {
  [AI_METRICS.DUO_USED_COUNT]: DuoUsedCountQuery,
  [AI_METRICS.DUO_AGENT_PLATFORM_CHATS]: DuoAgentPlatformChatsQuery,
  [AI_METRICS.DUO_AGENT_PLATFORM_AGENTS_FLOWS_USERS_COUNT]:
    DuoAgentPlatformAgentFlowsUsersCountQuery,
  [AI_METRICS.DUO_POWER_USERS_COUNT]: DuoPowerUsersCountQuery,
  [AI_METRICS.DUO_PIPELINES_RATE]: DuoPipelinesRateQuery,
};

// Extracts a metric from a query result into a `{ value, description }` shape.
// `value` is the number used for display and trend calculation; `description` is optional
// supplementary text rendered below the value (for example the rate's numerator/denominator).
const extractMetricData = ({ metric, result }) => {
  const resp = extractAiMetricsResponse(result);

  switch (metric) {
    case AI_METRICS.DUO_USED_COUNT:
      return { value: resp.duoUsedCount };

    case AI_METRICS.DUO_AGENT_PLATFORM_CHATS: {
      const { agentPlatformChats: { createdSessionEventCount } = {} } = resp;

      return { value: createdSessionEventCount };
    }

    case AI_METRICS.DUO_AGENT_PLATFORM_AGENTS_FLOWS_USERS_COUNT: {
      const analyticsResponse = extractQueryResponseFromNamespace({
        result,
        resultKey: 'analytics',
      });

      return {
        value: analyticsResponse?.agentPlatformSessions?.aggregated?.nodes?.[0]?.usersCount,
      };
    }

    case AI_METRICS.DUO_POWER_USERS_COUNT: {
      const analyticsResponse = extractQueryResponseFromNamespace({
        result,
        resultKey: 'analytics',
      });

      return { value: analyticsResponse?.duoUsageEvents?.aggregated?.count };
    }

    case AI_METRICS.DUO_PIPELINES_RATE: {
      const { pipelines } =
        extractQueryResponseFromNamespace({ result, resultKey: 'analytics' }) || {};
      const pipelineCounts = pipelines?.aggregated?.nodes?.[0];
      const duoTotal = pipelineCounts?.duoPipelinesCount ?? 0;
      const allTotal = pipelineCounts?.allPipelinesCount ?? 0;
      const value = calculateRate({ numerator: duoTotal, denominator: allTotal });

      return {
        value,
        description: isNil(value)
          ? undefined
          : sprintf(s__('AiImpactAnalytics|%{duoCount}/%{allCount} pipelines'), {
              duoCount: formatNumber(duoTotal),
              allCount: formatNumber(allTotal),
            }),
      };
    }

    default:
      return { value: null };
  }
};

const fetchMetric = async ({ metric, namespace, startDate, endDate }) => {
  const query = METRIC_QUERIES[metric];

  if (!query) {
    throw new Error(
      sprintf(s__('AiImpactAnalytics|No query found for metric: %{metric}'), { metric }),
    );
  }

  const result = await defaultClient.query({
    query,
    variables: {
      fullPath: namespace,
      startDate: toISODateFormat(startDate, true),
      endDate: toISODateFormat(endDate, true),
    },
  });

  return extractMetricData({ metric, result });
};

const fetchAiImpactQuery = async ({ metric, namespace, startDate, endDate, previousRange }) => {
  const current = await fetchMetric({ metric, namespace, startDate, endDate });
  const previous = await fetchMetric({ metric, namespace, ...previousRange });

  return { current, previous };
};

export default async function fetch({
  namespace,
  query: { metric, dateRange, ...overridesRest } = {},
  setVisualizationOverrides = () => {},
}) {
  // Default to 30 days if an invalid date range is given
  const {
    startDate,
    endDate,
    previousRange,
    text: subtitle,
  } = getDateRange(dateRange, DATE_RANGE_OPTION_LAST_30_DAYS);

  const { current, previous } = await fetchAiImpactQuery({
    metric,
    namespace,
    startDate,
    endDate,
    previousRange,
    ...overridesRest,
  });

  const { value: currentValue, description } = current;
  const { value: previousValue } = previous;

  const { value: change, tooltip: metaTooltip } = calculateChange(currentValue, previousValue, {
    validValueTooltip: s__(
      'AiImpactAnalytics|Percentage change compared to the previous time period.',
    ),
    noPreviousDataTooltip: s__(
      "AiImpactAnalytics|Value can't be calculated due to insufficient data. No data is available for the previous time period.",
    ),
  });

  const { units } = AI_IMPACT_OVER_TIME_METRICS[metric] ?? {};

  setVisualizationOverrides({
    visualizationOptionOverrides: {
      subtitle,
      description,
      tooltip: AI_IMPACT_OVER_TIME_METRICS_TOOLTIPS[metric],
      metaTooltip,
      ...getBadgeTrendIndicator({ change }),
    },
  });

  if (isNil(currentValue)) return '-';

  // scaledValueForDisplay expects a value between 0 -> 1
  return units === UNITS.PERCENT
    ? scaledValueForDisplay(currentValue / 100, units)
    : formatNumber(currentValue);
}
