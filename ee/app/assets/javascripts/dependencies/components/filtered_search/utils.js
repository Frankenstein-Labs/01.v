import { OPERATORS_OR } from '~/vue_shared/components/filtered_search_bar/constants';
import TrackedRefToken from 'ee/security_dashboard/components/shared/filtered_search/tokens/tracked_ref_token.vue';

export const isTrackedRefFilterEnabled = ({
  glFeatures = {},
  projectFullPath = '',
  defaultBranchContext = null,
} = {}) =>
  Boolean(
    glFeatures.vulnerabilitiesAcrossContexts &&
    glFeatures.projectDependencyTrackedRef &&
    projectFullPath &&
    defaultBranchContext,
  );

export const buildDefaultTrackedRefFilter = (defaultBranchContext) => {
  const data = TrackedRefToken.defaultValues({ defaultBranchContext });

  if (!data.length) {
    return [];
  }

  return [
    {
      type: 'trackedRefIds',
      value: { data, operator: OPERATORS_OR[0].value },
    },
  ];
};
