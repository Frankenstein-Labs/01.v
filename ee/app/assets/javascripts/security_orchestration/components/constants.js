import { s__ } from '~/locale';

export const NEW_POLICY_BUTTON_TEXT = s__('SecurityOrchestration|New policy');
export const SCAN_EXECUTION_POLICY_TYPE_HEADER = s__('SecurityOrchestration|Scan execution');
export const MERGE_REQUEST_APPROVAL_POLICY_TYPE_HEADER = s__(
  'SecurityOrchestration|Merge request approval',
);
export const PIPELINE_EXECUTION_POLICY_TYPE_HEADER = s__(
  'SecurityOrchestration|Pipeline execution',
);
export const PIPELINE_EXECUTION_SCHEDULE_POLICY_TYPE_HEADER = s__(
  'SecurityOrchestration|Scheduled pipeline execution',
);
export const VULNERABILITY_MANAGEMENT_POLICY_TYPE_HEADER = s__(
  'SecurityOrchestration|Vulnerability management',
);
export const DEPENDENCY_FIREWALL_POLICY_TYPE_HEADER = s__(
  'SecurityOrchestration|Dependency firewall',
);

export const SCAN_EXECUTION_POLICY_TYPE = 'scan_execution_policy';
export const APPROVAL_POLICY_TYPE = 'approval_policy';
export const PIPELINE_EXECUTION_POLICY_TYPE = 'pipeline_execution_policy';
export const PIPELINE_EXECUTION_SCHEDULE_POLICY_TYPE = 'pipeline_execution_schedule_policy';
export const VULNERABILITY_MANAGEMENT_POLICY_TYPE = 'vulnerability_management_policy';
export const DEPENDENCY_FIREWALL_POLICY_TYPE = 'dependency_firewall_policy';

export const POLICY_TYPE_COMPONENT_OPTIONS = {
  scanExecution: {
    component: 'scan-execution-policy-editor',
    text: SCAN_EXECUTION_POLICY_TYPE_HEADER,
    typeName: 'ScanExecutionPolicy',
    urlParameter: SCAN_EXECUTION_POLICY_TYPE,
    value: 'scanExecution',
  },
  legacyApproval: {
    component: 'scan-result-policy-editor',
    text: MERGE_REQUEST_APPROVAL_POLICY_TYPE_HEADER,
    typeName: 'ScanResultPolicy',
    urlParameter: APPROVAL_POLICY_TYPE,
    value: 'approval',
  },
  approval: {
    // used by Group.approvalPolicies
    component: 'scan-result-policy-editor',
    text: MERGE_REQUEST_APPROVAL_POLICY_TYPE_HEADER,
    typeName: 'ApprovalPolicy',
    urlParameter: APPROVAL_POLICY_TYPE,
    value: 'approval',
  },
  pipelineExecution: {
    component: 'pipeline-execution-policy-editor',
    text: PIPELINE_EXECUTION_POLICY_TYPE_HEADER,
    typeName: 'PipelineExecutionPolicy',
    urlParameter: PIPELINE_EXECUTION_POLICY_TYPE,
    value: 'pipeline',
  },
  pipelineExecutionSchedule: {
    component: 'pipeline-execution-policy-editor',
    text: PIPELINE_EXECUTION_SCHEDULE_POLICY_TYPE_HEADER,
    typeName: 'PipelineExecutionSchedulePolicy',
    urlParameter: PIPELINE_EXECUTION_SCHEDULE_POLICY_TYPE,
    value: 'pipeline_schedule',
  },
  vulnerabilityManagement: {
    component: 'vulnerability-management-policy-editor',
    text: VULNERABILITY_MANAGEMENT_POLICY_TYPE_HEADER,
    typeName: 'VulnerabilityManagementPolicy',
    urlParameter: VULNERABILITY_MANAGEMENT_POLICY_TYPE,
    value: 'vulnerabilityManagement',
  },
  dependencyFirewall: {
    component: 'dependency-firewall-policy-editor',
    text: DEPENDENCY_FIREWALL_POLICY_TYPE_HEADER,
    typeName: 'DependencyFirewallPolicy',
    urlParameter: DEPENDENCY_FIREWALL_POLICY_TYPE,
    value: 'dependencyFirewall',
  },
};

export const POLICIES_LIST_CONTAINER_CLASS = '.js-security-policies-container-wrapper';

export const DEFAULT_SKIP_SI_CONFIGURATION = { allowed: true };
export const DEFAULT_REVERSED_SKIP_SI_CONFIGURATION = { allowed: false };
