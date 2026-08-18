import { NAMESPACE_TYPES } from 'ee/security_orchestration/constants';

export const DEFAULT_PROVIDE = {
  designatedAsCsp: false,
  disableScanPolicyUpdate: false,
  disableSecurityPolicyProject: false,
  policyEditorEmptyStateSvgPath: 'path/to/svg',
  namespaceId: 1,
  namespacePath: 'path/to/project',
  namespaceType: NAMESPACE_TYPES.PROJECT,
  scanPolicyDocumentationPath: 'path/to/policy-docs',
  assignedPolicyProject: {},
  enabledExperiments: [],
  globalGroupApproversEnabled: false,
  maxActiveScanExecutionPoliciesReached: false,
  maxActiveScanResultPoliciesReached: false,
  maxActivePipelineExecutionPoliciesReached: false,
  maxActiveVulnerabilityManagementPoliciesReached: false,
  maxPipelineExecutionPoliciesAllowed: 1,
  maxScanExecutionPoliciesAllowed: 5,
  maxScanResultPoliciesAllowed: 5,
  maxVulnerabilityManagementPoliciesAllowed: 5,
  maxScanExecutionPolicyActions: 10,
  policiesPath: 'path/to/policies',
  roleApproverTypes: [],
  rootNamespacePath: 'path/to/root',
  parsedSoftwareLicenses: [],
  timezones: [],
  existingPolicy: undefined,
  policyEditorEnabled: false,
};

export const SCAN_EXECUTION_POLICY = 'scan_execution_policy';
export const PIPELINE_EXECUTION_POLICY = 'pipeline_execution_policy';
export const APPROVAL_POLICY = 'approval_policy';

export const SCAN_EXECUTION_DEFAULT = {
  rules: `    rules:
      - type: pipeline
        branch_type: default
      - type: pipeline
        branch_type: target_default
        pipeline_sources:
          including:
            - merge_request_event`,

  actions: `    actions:
      - scan: secret_detection
        template: latest
        variables:
          SECURE_ENABLE_LOCAL_CONFIGURATION: 'false'`,

  skip: `    skip_ci:
      allowed: true`,
};
