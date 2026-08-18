import { s__ } from '~/locale';
import DuoFeatureUsageQuery from '~/analytics/dashboards/ai_impact/graphql/duo_feature_usage.query.graphql';
import { calculateChange } from 'ee/analytics/dashboards/ai_impact/utils';
import { extractAiMetricsResponse } from 'ee/analytics/dashboards/ai_impact/api';
import { DATE_RANGE_OPTION_LAST_30_DAYS } from 'ee/analytics/analytics_dashboards/components/filters/constants';
import { toISODateFormat } from '~/lib/utils/datetime_utility';
import { getDateRange } from '~/explore/analytics_dashboards/components/utils';
import { defaultClient } from '../graphql/client';

const fetchMetrics = async ({ namespace, startDate, endDate }) => {
  const result = await defaultClient.query({
    query: DuoFeatureUsageQuery,
    variables: {
      fullPath: namespace,
      startDate: toISODateFormat(startDate, true),
      endDate: toISODateFormat(endDate, true),
    },
  });

  return extractAiMetricsResponse(result);
};

const fetchFeatureUsage = async ({ namespace, startDate, endDate, previousRange }) => {
  const currentMetrics = await fetchMetrics({ namespace, startDate, endDate });
  const previousMetrics = await fetchMetrics({ namespace, ...previousRange });

  return [
    {
      featureName: s__('AnalyticsDashboards|Code Suggestions'),
      userCount: currentMetrics.codeSuggestions.contributorsCount,
      eventCount: currentMetrics.codeSuggestions.shownCount,
      percentChange: calculateChange(
        currentMetrics.codeSuggestions.shownCount,
        previousMetrics.codeSuggestions.shownCount,
      ),
    },
    {
      featureName: s__('AnalyticsDashboards|Chat (non-agentic)'),
      userCount: currentMetrics.duoChatContributorsCount,
      eventCount: currentMetrics.chat.requestDuoChatResponseEventCount,
      percentChange: calculateChange(
        currentMetrics.chat.requestDuoChatResponseEventCount,
        previousMetrics.chat.requestDuoChatResponseEventCount,
      ),
    },
    {
      featureName: s__('AnalyticsDashboards|Root Cause Analysis'),
      userCount: currentMetrics.rootCauseAnalysisUsersCount,
      eventCount: currentMetrics.troubleshoot.troubleshootJobEventCount,
      percentChange: calculateChange(
        currentMetrics.troubleshoot.troubleshootJobEventCount,
        previousMetrics.troubleshoot.troubleshootJobEventCount,
      ),
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
    previousRange,
    text: subtitle,
  } = getDateRange(dateRange, DATE_RANGE_OPTION_LAST_30_DAYS);

  setVisualizationOverrides({
    visualizationOptionOverrides: {
      subtitle,
      tooltip: {
        description: s__(
          "AnalyticsDashboards|This table doesn't include GitLab Duo Agent Platform events.",
        ),
      },
    },
  });

  const nodes = await fetchFeatureUsage({
    namespace,
    startDate,
    endDate,
    previousRange,
  });

  return { nodes };
}
