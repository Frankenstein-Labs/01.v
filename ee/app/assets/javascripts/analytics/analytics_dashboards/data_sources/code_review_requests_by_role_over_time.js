import AiMetricsQuery from '~/analytics/dashboards/ai_impact/graphql/ai_metrics.query.graphql';
import { DATE_RANGE_OPTION_LAST_180_DAYS } from 'ee/analytics/analytics_dashboards/components/filters/constants';
import { getDateRange } from '~/explore/analytics_dashboards/components/utils';
import { defaultClient } from 'ee/analytics/analytics_dashboards/graphql/client';
import { extractQueryResponseFromNamespace } from '~/analytics/shared/utils';
import { s__ } from '~/locale';
import { getMonthsInDateRange } from 'ee/analytics/dashboards/utils';
import { helpPagePath } from '~/helpers/help_page_helper';

const extractCodeReviewRequestsByRoleMetrics = (result) => {
  const { codeReview } = extractQueryResponseFromNamespace({
    result,
    resultKey: 'aiMetrics',
  });

  const {
    requestReviewDuoCodeReviewOnMrByAuthorEventCount,
    requestReviewDuoCodeReviewOnMrByNonAuthorEventCount,
  } = codeReview ?? {};

  return {
    requestReviewDuoCodeReviewOnMrByAuthorEventCount,
    requestReviewDuoCodeReviewOnMrByNonAuthorEventCount,
  };
};

const codeReviewRequestsByRoleQuery = async ({ namespace, startDate, endDate }) => {
  const result = await defaultClient.query({
    query: AiMetricsQuery,
    variables: {
      fullPath: namespace,
      startDate,
      endDate,
    },
  });

  return extractCodeReviewRequestsByRoleMetrics(result);
};

const formatChartData = (result = [], monthsData = []) => ({
  bars: [
    {
      name: s__('CodeReviewRequestsByRoleChart|Requests by authors'),
      data: result.map(
        ({ requestReviewDuoCodeReviewOnMrByAuthorEventCount }) =>
          requestReviewDuoCodeReviewOnMrByAuthorEventCount,
      ),
    },
    {
      name: s__('CodeReviewRequestsByRoleChart|Requests by non-authors'),
      data: result.map(
        ({ requestReviewDuoCodeReviewOnMrByNonAuthorEventCount }) =>
          requestReviewDuoCodeReviewOnMrByNonAuthorEventCount,
      ),
    },
  ],
  groupBy: monthsData.map(({ monthLabel }) => monthLabel),
});

const fetchCodeReviewRequestsByRoleData = async ({ namespace, startDate, endDate }) => {
  const monthsData = getMonthsInDateRange(startDate, endDate);
  const promises = monthsData.map(({ fromDate, toDate }) =>
    codeReviewRequestsByRoleQuery({
      namespace,
      startDate: fromDate,
      endDate: toDate,
    }),
  );

  const result = await Promise.all(promises);

  return formatChartData(result, monthsData);
};

const hasChartData = (chartData = []) => chartData.some(({ data }) => data.some((value) => value));

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

  const chartData = await fetchCodeReviewRequestsByRoleData({
    namespace: namespaceOverride ?? namespace,
    startDate,
    endDate,
  });

  const descriptionLink = helpPagePath('user/analytics/duo_and_sdlc_trends', {
    anchor: 'gitlab-duo-code-review-requests-by-role',
  });

  setVisualizationOverrides({
    visualizationOptionOverrides: {
      subtitle,
      tooltip: {
        description: s__(
          'CodeReviewRequestsByRoleChart|Tracks users who initiated GitLab Duo Code Review. %{linkStart}Learn more%{linkEnd}.',
        ),
        descriptionLink,
      },
    },
  });

  if (!hasChartData(chartData.bars)) return {};
  return chartData;
}
