import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { initVueApp } from '~/lib/utils/vue3compat/init_vue_app';
import createDefaultClient from '~/lib/graphql';
import { convertObjectPropsToCamelCase, parseBoolean } from '~/lib/utils/common_utils';
import SecurityPoliciesListApp from './components/policies/app.vue';
import {
  DEFAULT_ASSIGNED_POLICY_PROJECT,
  MAX_SCAN_EXECUTION_ACTION_COUNT,
  MAX_SCAN_EXECUTION_POLICY_SCHEDULED_RULES_COUNT,
} from './constants';

Vue.use(VueApollo);

const apolloProvider = new VueApollo({
  defaultClient: createDefaultClient(
    {},
    {
      cacheConfig: { typePolicies: { ScanExecutionPolicy: { keyFields: ['name', 'source'] } } },
    },
  ),
});

export default (el, namespaceType) => {
  if (!el) return null;

  const {
    accessTokens,
    assignedPolicyProject,
    designatedAsCsp,
    disableSecurityPolicyProject,
    disableScanPolicyUpdate,
    emptyFilterSvgPath,
    emptyListSvgPath,
    documentationPath,
    newPolicyPath,
    namespacePath,
    rootNamespacePath,
    maxScanExecutionPolicyActions,
    maxScanExecutionPolicySchedules,
  } = el.dataset;

  let parsedAssignedPolicyProject;
  let parsedAccessTokens;

  try {
    parsedAssignedPolicyProject = convertObjectPropsToCamelCase(JSON.parse(assignedPolicyProject));
  } catch {
    parsedAssignedPolicyProject = DEFAULT_ASSIGNED_POLICY_PROJECT;
  }

  try {
    parsedAccessTokens = JSON.parse(accessTokens);
  } catch {
    parsedAccessTokens = [];
  }

  const count = parseInt(maxScanExecutionPolicyActions, 10);
  const parsedMaxScanExecutionPolicyActions = Number.isNaN(count)
    ? MAX_SCAN_EXECUTION_ACTION_COUNT
    : count;

  const parsedMaxScanExecutionPolicySchedules = parseInt(maxScanExecutionPolicySchedules, 10);
  const sanitizedMaxScanExecutionPolicySchedules = Number.isNaN(
    parsedMaxScanExecutionPolicySchedules,
  )
    ? MAX_SCAN_EXECUTION_POLICY_SCHEDULED_RULES_COUNT
    : parsedMaxScanExecutionPolicySchedules;

  return initVueApp({
    apolloProvider,
    el,
    name: 'PoliciesAppRoot',
    provide: {
      availableAccessTokens: parsedAccessTokens,
      assignedPolicyProject: parsedAssignedPolicyProject,
      designatedAsCsp: parseBoolean(designatedAsCsp),
      disableSecurityPolicyProject: parseBoolean(disableSecurityPolicyProject),
      disableScanPolicyUpdate: parseBoolean(disableScanPolicyUpdate),
      documentationPath,
      newPolicyPath,
      emptyFilterSvgPath,
      emptyListSvgPath,
      namespacePath,
      namespaceType,
      rootNamespacePath,
      maxScanExecutionPolicyActions: parsedMaxScanExecutionPolicyActions,
      maxScanExecutionPolicySchedules: sanitizedMaxScanExecutionPolicySchedules,
    },
    component: SecurityPoliciesListApp,
  });
};
