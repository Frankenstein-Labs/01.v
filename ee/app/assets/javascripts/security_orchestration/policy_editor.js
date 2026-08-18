import { initVueApp } from '~/lib/utils/vue3compat/init_vue_app';
import { convertObjectPropsToCamelCase, parseBoolean } from '~/lib/utils/common_utils';
import apolloProvider from 'ee/vue_shared/security_configuration/graphql/provider';
import App from './components/policy_editor/app.vue';
import { DEFAULT_ASSIGNED_POLICY_PROJECT, MAX_SCAN_EXECUTION_ACTION_COUNT } from './constants';

export default (el, namespaceType) => {
  if (!el) return null;

  const {
    accessTokens,
    assignedPolicyProject,
    designatedAsCsp,
    disableScanPolicyUpdate,
    enabledExperiments,
    globalGroupApproversEnabled,
    maxActiveScanExecutionPoliciesReached,
    maxActiveScanResultPoliciesReached,
    maxActivePipelineExecutionPoliciesReached,
    maxActiveVulnerabilityManagementPoliciesReached,
    maxScanExecutionPoliciesAllowed,
    maxScanResultPoliciesAllowed,
    maxPipelineExecutionPoliciesAllowed,
    maxVulnerabilityManagementPoliciesAllowed,
    namespaceId,
    namespacePath,
    policyEditorEnabled,
    policiesPath,
    policy,
    policyEditorEmptyStateSvgPath,
    policyType,
    roleApproverTypes,
    rootNamespacePath,
    scanPolicyDocumentationPath,
    softwareLicenses,
    timezones,
    maxScanExecutionPolicyActions,
  } = el.dataset;

  let parsedAssignedPolicyProject;

  try {
    parsedAssignedPolicyProject = convertObjectPropsToCamelCase(JSON.parse(assignedPolicyProject));
  } catch {
    parsedAssignedPolicyProject = DEFAULT_ASSIGNED_POLICY_PROJECT;
  }

  let parsedSoftwareLicenses;
  let parsedTimezones;
  let parsedAccessTokens;

  try {
    parsedSoftwareLicenses = JSON.parse(softwareLicenses).map((license) => {
      return { value: license, text: license };
    });
  } catch {
    parsedSoftwareLicenses = [];
  }

  try {
    parsedTimezones = JSON.parse(timezones);
  } catch {
    parsedTimezones = [];
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

  return initVueApp({
    el,
    apolloProvider,
    provide: {
      availableAccessTokens: parsedAccessTokens,
      designatedAsCsp: parseBoolean(designatedAsCsp),
      disableScanPolicyUpdate: parseBoolean(disableScanPolicyUpdate),
      enabledExperiments,
      globalGroupApproversEnabled: parseBoolean(globalGroupApproversEnabled),
      maxActiveScanExecutionPoliciesReached: parseBoolean(maxActiveScanExecutionPoliciesReached),
      maxActivePipelineExecutionPoliciesReached: parseBoolean(
        maxActivePipelineExecutionPoliciesReached,
      ),
      maxActiveScanResultPoliciesReached: parseBoolean(maxActiveScanResultPoliciesReached),
      maxActiveVulnerabilityManagementPoliciesReached: parseBoolean(
        maxActiveVulnerabilityManagementPoliciesReached,
      ),
      maxScanExecutionPoliciesAllowed,
      maxScanResultPoliciesAllowed,
      maxPipelineExecutionPoliciesAllowed,
      maxVulnerabilityManagementPoliciesAllowed,
      namespaceId,
      namespacePath,
      namespaceType,
      policyEditorEmptyStateSvgPath,
      policyEditorEnabled: parseBoolean(policyEditorEnabled),
      policiesPath,
      roleApproverTypes: JSON.parse(roleApproverTypes),
      rootNamespacePath,
      scanPolicyDocumentationPath,
      parsedSoftwareLicenses,
      timezones: parsedTimezones,
      existingPolicy: policy ? { type: policyType, ...JSON.parse(policy) } : undefined,
      assignedPolicyProject: parsedAssignedPolicyProject,
      maxScanExecutionPolicyActions: parsedMaxScanExecutionPolicyActions,
    },
    component: App,
  });
};
