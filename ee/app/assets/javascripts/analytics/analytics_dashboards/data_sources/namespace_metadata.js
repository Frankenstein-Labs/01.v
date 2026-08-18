import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import {
  GROUP_VISIBILITY_TYPE,
  PROJECT_VISIBILITY_TYPE,
  VISIBILITY_TYPE_ICON,
} from '~/visibility_level/constants';
import { s__, __, sprintf } from '~/locale';
import GetGroupOrProjectQuery from '~/analytics/dashboards/graphql/get_group_or_project.query.graphql';
import { GENERIC_DASHBOARD_ERROR } from 'ee/analytics/dashboards/constants';
import { defaultClient } from '../graphql/client';

/**
 * Takes the namespace query response, extracts its data
 * and formats it for rendering.
 */
export const extractNamespaceMetadata = ({ data = {}, isProjectNamespace = false } = {}) => {
  const baseNamespaceData = {
    id: getIdFromGraphQLId(data?.id),
    avatarUrl: data?.avatarUrl,
    fullName: data?.fullName,
    visibilityLevelIcon: VISIBILITY_TYPE_ICON[data?.visibility],
  };

  if (isProjectNamespace) {
    return {
      ...baseNamespaceData,
      namespaceType: __('Project'),
      namespaceTypeIcon: 'project',
      visibilityLevelTooltip: PROJECT_VISIBILITY_TYPE[data?.visibility],
    };
  }

  return {
    ...baseNamespaceData,
    namespaceType: __('Group'),
    namespaceTypeIcon: 'group',
    visibilityLevelTooltip: GROUP_VISIBILITY_TYPE[data?.visibility],
  };
};

/**
 * Fetch metadata for a given namespace
 */
export default function fetch({
  title,
  namespace,
  setAlerts,
  query: { namespace: namespaceOverride } = {},
  setVisualizationOverrides = () => {},
}) {
  const fullPath = namespaceOverride || namespace;

  if (!fullPath) return {};

  const request = defaultClient.query({
    query: GetGroupOrProjectQuery,
    variables: {
      fullPath,
    },
  });

  return request
    .then(({ data = {} }) => {
      const namespaceMetadata = data?.group || data?.project;
      const isProjectNamespace = Boolean(data?.project);

      if (!namespaceMetadata) return {};

      if (title) {
        const interpolatedTitle = sprintf(title, {
          namespaceName: namespaceMetadata.name,
          namespaceType: data.project ? __('project') : __('group'),
          namespaceFullPath: fullPath,
        });
        setVisualizationOverrides({
          visualizationOptionOverrides: { title: interpolatedTitle },
        });
      }

      return extractNamespaceMetadata({ data: namespaceMetadata, isProjectNamespace });
    })
    .catch(() => {
      setAlerts({
        title: GENERIC_DASHBOARD_ERROR,
        errors: [s__('AnalyticsDashboards|Failed to load namespace metadata.')],
      });
    });
}
