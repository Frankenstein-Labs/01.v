import { pick } from 'lodash-es';
import { s__, __, sprintf } from '~/locale';
import { convertObjectPropsToCamelCase } from '~/lib/utils/common_utils';
import GetGroupOrProjectQuery from '~/analytics/dashboards/graphql/get_group_or_project.query.graphql';
import { defaultClient } from '../graphql/client';

const I18N_VSD_DORA_METRICS_PANEL_TITLE = s__('DORA4Metrics|Metrics comparison for %{name}');

const ALLOWED_FILTER_KEYS = ['includeMetrics', 'excludeMetrics', 'labels', 'projectTopics'];

const generatePanelTitle = ({ namespace: { name } }) => {
  return sprintf(I18N_VSD_DORA_METRICS_PANEL_TITLE, { name });
};

export default async function fetch({
  title,
  namespace,
  query: { filters = {} } = {},
  setVisualizationOverrides = () => {},
}) {
  const { data: namespaceReq } = await defaultClient.query({
    query: GetGroupOrProjectQuery,
    variables: {
      fullPath: namespace,
    },
  });

  const resolvedNamespace = namespaceReq?.project ?? namespaceReq?.group;

  if (!resolvedNamespace) return {};

  const namespaceType = namespaceReq.project ? __('project') : __('group');
  const namespaceName = resolvedNamespace.name;

  if (title) {
    setVisualizationOverrides({
      visualizationOptionOverrides: {
        title: sprintf(title, {
          namespaceFullPath: namespace,
          namespaceName,
          namespaceType,
        }),
      },
    });
  }
  return convertObjectPropsToCamelCase(
    {
      namespace,
      title: title || generatePanelTitle({ namespace }),
      filters: pick(filters, ALLOWED_FILTER_KEYS),
    },
    { deep: true },
  );
}
