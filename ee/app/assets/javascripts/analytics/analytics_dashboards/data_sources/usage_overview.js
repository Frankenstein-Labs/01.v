import { compact } from 'lodash-es';
import {
  USAGE_OVERVIEW_QUERY_INCLUDE_KEYS,
  USAGE_OVERVIEW_METADATA,
  USAGE_OVERVIEW_DEFAULT_DATE_RANGE,
  USAGE_OVERVIEW_NO_DATA_ERROR,
  USAGE_OVERVIEW_IDENTIFIER_GROUPS,
  USAGE_OVERVIEW_IDENTIFIER_PROJECTS,
  USAGE_OVERVIEW_IDENTIFIER_USERS,
  USAGE_OVERVIEW_IDENTIFIER_ISSUES,
  USAGE_OVERVIEW_IDENTIFIER_MERGE_REQUESTS,
  USAGE_OVERVIEW_IDENTIFIER_PIPELINES,
} from '~/analytics/shared/constants';
import { toYmd } from '~/analytics/shared/utils';
import { __, s__, sprintf } from '~/locale';
import {
  GROUP_VISIBILITY_TYPE,
  PROJECT_VISIBILITY_TYPE,
  VISIBILITY_TYPE_ICON,
} from '~/visibility_level/constants';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import { localeDateFormat } from '~/lib/utils/datetime/locale_dateformat';
import { isValidDate, newDate } from '~/lib/utils/datetime_utility';
import { defaultClient } from '../graphql/client';
import getUsageOverviewQuery from '../graphql/queries/get_usage_overview.query.graphql';

const USAGE_OVERVIEW_IDENTIFIERS = [
  USAGE_OVERVIEW_IDENTIFIER_GROUPS,
  USAGE_OVERVIEW_IDENTIFIER_PROJECTS,
  USAGE_OVERVIEW_IDENTIFIER_USERS,
  USAGE_OVERVIEW_IDENTIFIER_ISSUES,
  USAGE_OVERVIEW_IDENTIFIER_MERGE_REQUESTS,
  USAGE_OVERVIEW_IDENTIFIER_PIPELINES,
];

/**
 * Takes the usage overview query response, extracts information
 * about the namespace and formats it for rendering.
 */
export const extractUsageNamespaceData = ({ data = {}, isProjectNamespace = false } = {}) => {
  const baseNamespaceData = {
    id: getIdFromGraphQLId(data?.id),
    avatarUrl: data?.avatarUrl,
    visibilityLevelIcon: VISIBILITY_TYPE_ICON[data?.visibility],
  };

  if (isProjectNamespace) {
    return {
      ...baseNamespaceData,
      fullName: data?.nameWithNamespace,
      namespaceType: __('Project'),
      visibilityLevelTooltip: PROJECT_VISIBILITY_TYPE[data?.visibility],
    };
  }

  return {
    ...baseNamespaceData,
    fullName: data?.fullName,
    namespaceType: __('Group'),
    visibilityLevelTooltip: GROUP_VISIBILITY_TYPE[data?.visibility],
  };
};

/**
 * Takes a usage metrics query response, extracts the values and
 * adds the additional metadata we need for rendering.
 */
export const extractUsageMetrics = (data) => {
  const keys = Object.keys(data);
  return USAGE_OVERVIEW_IDENTIFIERS.reduce((acc, identifier) => {
    if (!keys.includes(identifier)) return acc;
    return [
      ...acc,
      {
        identifier,
        value: data[identifier]?.count || 0,
        recordedAt: data[identifier]?.recordedAt,
        ...USAGE_OVERVIEW_METADATA[identifier],
      },
    ];
  }, []);
};

/**
 * Returns the most recent recorded timestamp from usage metrics query response
 */
export const getMostRecentRecordedAt = (data = []) => {
  const allRecordedAt = compact(data.map((metric) => metric.recordedAt));
  const [mostRecentRecordedAt] = allRecordedAt.sort().slice(-1);
  const date = newDate(mostRecentRecordedAt);

  if (!isValidDate(date)) return null;

  return localeDateFormat.asDateTime.format(newDate(date));
};

const usageOverviewNoData = extractUsageMetrics({
  [USAGE_OVERVIEW_IDENTIFIER_GROUPS]: {
    identifier: USAGE_OVERVIEW_IDENTIFIER_GROUPS,
    count: 0,
  },
  [USAGE_OVERVIEW_IDENTIFIER_PROJECTS]: {
    identifier: USAGE_OVERVIEW_IDENTIFIER_PROJECTS,
    count: 0,
  },
  [USAGE_OVERVIEW_IDENTIFIER_USERS]: {
    identifier: USAGE_OVERVIEW_IDENTIFIER_USERS,
    count: 0,
  },
  [USAGE_OVERVIEW_IDENTIFIER_ISSUES]: {
    identifier: USAGE_OVERVIEW_IDENTIFIER_ISSUES,
    count: 0,
  },
  [USAGE_OVERVIEW_IDENTIFIER_MERGE_REQUESTS]: {
    identifier: USAGE_OVERVIEW_IDENTIFIER_MERGE_REQUESTS,
    count: 0,
  },
  [USAGE_OVERVIEW_IDENTIFIER_PIPELINES]: {
    identifier: USAGE_OVERVIEW_IDENTIFIER_PIPELINES,
    count: 0,
  },
});

/**
 * Constructs the query variables that specify the metrics
 * to be included in the response.
 */
export const prepareQuery = (queryKeysToInclude = []) => {
  const queryIncludeVariables = new Map();

  Object.entries(USAGE_OVERVIEW_QUERY_INCLUDE_KEYS).forEach(([identifier, key]) => {
    queryIncludeVariables.set(key, queryKeysToInclude.includes(identifier));
  });

  return Object.fromEntries(queryIncludeVariables);
};

/**
 * Fetch usage overview metrics for a given namespace
 */
export default async function fetch({
  title: panelTitle,
  namespace,
  query: {
    namespace: namespaceOverride,
    filters: { include = USAGE_OVERVIEW_IDENTIFIERS } = {},
  } = {},
  setVisualizationOverrides,
}) {
  const fullPath = namespaceOverride || namespace;
  const variableOverrides = prepareQuery(include);
  const { startDate, endDate } = USAGE_OVERVIEW_DEFAULT_DATE_RANGE;

  const request = defaultClient.query({
    query: getUsageOverviewQuery,
    variables: {
      fullPath,
      startDate: toYmd(startDate),
      endDate: toYmd(endDate),
      ...variableOverrides,
    },
  });

  return request
    .then(({ data = {} }) => {
      const usageOverviewData = data?.group || data?.project;
      const isProjectNamespace = Boolean(data?.project);
      const recordedAt = usageOverviewData
        ? getMostRecentRecordedAt(extractUsageMetrics(usageOverviewData))
        : null;

      const tooltipDescription = recordedAt
        ? sprintf(
            s__(
              'Analytics|Statistics on namespace usage. Usage data is a cumulative count, and updated monthly. Last updated: %{recordedAt}',
            ),
            { recordedAt },
          )
        : s__(
            'Analytics|Statistics on namespace usage. Usage data is a cumulative count, and updated monthly.',
          );

      const titleOverride = panelTitle
        ? {
            title: sprintf(panelTitle, {
              namespaceName: usageOverviewData?.name,
              namespaceType: isProjectNamespace ? __('project') : __('group'),
              namespaceFullPath: fullPath,
            }),
          }
        : {};

      setVisualizationOverrides({
        visualizationOptionOverrides: {
          ...titleOverride,
          tooltip: {
            description: tooltipDescription,
          },
        },
      });

      if (!usageOverviewData) {
        return { metrics: usageOverviewNoData };
      }

      return {
        namespace: extractUsageNamespaceData({ data: usageOverviewData, isProjectNamespace }),
        metrics: extractUsageMetrics(usageOverviewData),
      };
    })
    .catch(() => {
      throw new Error(USAGE_OVERVIEW_NO_DATA_ERROR);
    });
}
