import { orderBy } from 'lodash-es';
import DuoFeatureRetentionQuery from 'ee/analytics/analytics_dashboards/graphql/queries/get_duo_feature_retention.query.graphql';
import { DATE_RANGE_OPTION_LAST_180_DAYS } from 'ee/analytics/analytics_dashboards/components/filters/constants';
import { calculateRate } from '~/analytics/dashboards/ai_impact/utils';
import { extractQueryResponseFromNamespace } from '~/analytics/shared/utils';
import { getDateRange } from '~/explore/analytics_dashboards/components/utils';
import { s__ } from '~/locale';
import { helpPagePath } from '~/helpers/help_page_helper';
import { defaultClient } from '../graphql/client';

const DUO_RETENTION_GRANULARITY_WEEKLY = 'weekly';

const DUO_FEATURE_CODE_SUGGESTIONS = 'code_suggestions';
const DUO_FEATURE_CHAT = 'chat';
const DUO_FEATURE_TROUBLESHOOT_JOB = 'troubleshoot_job';
const DUO_FEATURE_CODE_REVIEW = 'code_review';

const DUO_FEATURE_SERIES_NAMES = {
  [DUO_FEATURE_CODE_SUGGESTIONS]: s__('AiImpactDashboard|Code Suggestions'),
  [DUO_FEATURE_CHAT]: s__('AiImpactDashboard|Duo Chat'),
  [DUO_FEATURE_TROUBLESHOOT_JOB]: s__('AiImpactDashboard|Root cause analysis'),
  [DUO_FEATURE_CODE_REVIEW]: s__('AiImpactDashboard|Duo Code Review'),
};

const DEFAULT_FEATURES = Object.keys(DUO_FEATURE_SERIES_NAMES);

export const asFeatureRetentionSeries = (nodes) => {
  const pointsByFeature = nodes.reduce(
    (acc, { dimensions, returningUsersCount, previousPeriodUsersCount }) => {
      const { feature, timestamp } = dimensions;
      const point = [
        new Date(timestamp),
        calculateRate({
          numerator: returningUsersCount,
          denominator: previousPeriodUsersCount,
          asDecimal: true,
        }) ?? 0,
      ];

      (acc[feature] ??= []).push(point);
      return acc;
    },
    {},
  );

  return Object.entries(pointsByFeature).map(([feature, points]) => ({
    name: DUO_FEATURE_SERIES_NAMES[feature] ?? feature,
    // Omit the earliest period: it has no preceding period to compare against,
    // so its retention is always 0 and would make the line start at zero.
    data: orderBy(points, ([date]) => date.getTime()).slice(1),
  }));
};

// The `aggregated` connection caps each page at 100 nodes, so a single request
// silently truncates once features × periods exceeds that (e.g. weekly
// granularity across the default features). Page through the
// cursor until the connection is exhausted.
const fetchAllAggregatedNodes = async (variables) => {
  const result = await defaultClient.query({
    query: DuoFeatureRetentionQuery,
    variables,
  });

  const { duoUsageEvents } =
    extractQueryResponseFromNamespace({ result, resultKey: 'analytics' }) ?? {};

  const { nodes = [], pageInfo = {} } = duoUsageEvents?.aggregated ?? {};

  if (pageInfo?.hasNextPage) {
    return nodes.concat(
      await fetchAllAggregatedNodes({
        ...variables,
        after: pageInfo.endCursor,
      }),
    );
  }

  return nodes;
};

const fetchFeatureRetention = async ({ namespace, ...variables }) => {
  const series = asFeatureRetentionSeries(
    await fetchAllAggregatedNodes({ fullPath: namespace, after: null, ...variables }),
  );

  return series.filter(({ data }) => data.length > 0);
};

export default function fetch({
  namespace,
  query: {
    dateRange,
    feature = DEFAULT_FEATURES,
    granularity = DUO_RETENTION_GRANULARITY_WEEKLY,
  } = {},
  setVisualizationOverrides = () => {},
}) {
  const {
    startDate,
    endDate,
    text: subtitle,
  } = getDateRange(dateRange, DATE_RANGE_OPTION_LAST_180_DAYS);
  // Fall back to the last 180 days when given an unknown date range.
  setVisualizationOverrides({
    visualizationOptionOverrides: {
      subtitle,
      tooltip: {
        description: s__(
          'ReturningGitlabDuoUsersByFeature|Percentage of users from the previous period who use the feature again in the selected period. %{linkStart}Learn more%{linkEnd}.',
        ),
        descriptionLink: helpPagePath('user/analytics/duo_and_sdlc_trends', {
          anchor: 'returning-gitlab-duo-users-by-feature',
        }),
      },
    },
  });

  return fetchFeatureRetention({
    namespace,
    startDate,
    endDate,
    feature,
    granularity,
  });
}
