import { s__ } from '~/locale';
import {
  DEPENDENCY_FIREWALL_POLICY_TYPE_HEADER,
  MERGE_REQUEST_APPROVAL_POLICY_TYPE_HEADER,
  PIPELINE_EXECUTION_POLICY_TYPE_HEADER,
  PIPELINE_EXECUTION_SCHEDULE_POLICY_TYPE_HEADER,
  SCAN_EXECUTION_POLICY_TYPE_HEADER,
  VULNERABILITY_MANAGEMENT_POLICY_TYPE_HEADER,
} from 'ee/security_orchestration/components/constants';
import { helpPagePath } from '~/helpers/help_page_helper';

export const POLICY_RELATIONSHIP_INHERITED = 'INHERITED';
export const POLICY_RELATIONSHIP_DIRECT = 'DIRECT';

export const POLICY_SOURCE_OPTIONS = {
  // The backend INHERITED relationship type is the most inclusive (returns direct + inherited
  // policies), so it serves as the "all sources" default. INHERITED_ONLY returns only inherited.
  ALL: {
    value: POLICY_RELATIONSHIP_INHERITED,
    text: s__('SecurityOrchestration|All sources'),
  },
  DIRECT: {
    value: POLICY_RELATIONSHIP_DIRECT,
    text: s__('SecurityOrchestration|Direct'),
  },
  INHERITED: {
    value: 'INHERITED_ONLY',
    text: s__('SecurityOrchestration|Inherited'),
  },
};

export const POLICY_TYPE_FILTER_OPTIONS = {
  ALL: {
    value: '',
    text: s__('SecurityOrchestration|All types'),
  },
  SCAN_EXECUTION: {
    value: 'SCAN_EXECUTION',
    text: SCAN_EXECUTION_POLICY_TYPE_HEADER,
  },
  APPROVAL: {
    value: 'APPROVAL',
    text: MERGE_REQUEST_APPROVAL_POLICY_TYPE_HEADER,
  },
  PIPELINE_EXECUTION: {
    value: 'PIPELINE_EXECUTION',
    text: PIPELINE_EXECUTION_POLICY_TYPE_HEADER,
  },
  PIPELINE_EXECUTION_SCHEDULE: {
    value: 'PIPELINE_EXECUTION_SCHEDULE',
    text: PIPELINE_EXECUTION_SCHEDULE_POLICY_TYPE_HEADER,
  },
  VULNERABILITY_MANAGEMENT: {
    value: 'VULNERABILITY_MANAGEMENT',
    text: VULNERABILITY_MANAGEMENT_POLICY_TYPE_HEADER,
  },
  DEPENDENCY_FIREWALL: {
    value: 'DEPENDENCY_FIREWALL',
    text: DEPENDENCY_FIREWALL_POLICY_TYPE_HEADER,
  },
};

export const APPROVAL_POLICY_FILTER_TYPE = 'APPROVAL_POLICY';

export const PIPELINE_TYPE_COMBINED_TYPE_MAP = {
  SCAN_EXECUTION: 'SCAN_EXECUTION_POLICY',
  APPROVAL: APPROVAL_POLICY_FILTER_TYPE,
  PIPELINE_EXECUTION: 'PIPELINE_EXECUTION_POLICY',
  PIPELINE_EXECUTION_SCHEDULE: 'PIPELINE_EXECUTION_SCHEDULE_POLICY',
  VULNERABILITY_MANAGEMENT: 'VULNERABILITY_MANAGEMENT_POLICY',
  DEPENDENCY_FIREWALL: 'DEPENDENCY_FIREWALL_POLICY',
};

export const EMPTY_LIST_DESCRIPTION = s__(
  'SecurityOrchestration|This %{namespaceType} does not contain any security policies.',
);

export const EMPTY_POLICY_PROJECT_DESCRIPTION = s__(
  'SecurityOrchestration|This %{namespaceType} is not linked to a security policy project. Create a policy, which also creates and links a security policy project. Alternatively, %{linkStart}link this %{namespaceType} to an existing security policy project%{linkEnd}.',
);

export const DEPRECATED_CUSTOM_SCAN_PROPERTY = 'custom_scan';

export const BREAKING_CHANGES_POPOVER_CONTENTS = {
  [POLICY_TYPE_FILTER_OPTIONS.APPROVAL.text]: {
    content: s__(
      'SecurityOrchestration|You must edit the policy and replace the deprecated syntax (%{deprecatedProperties}). For details on its replacement, see the %{linkStart}policy documentation%{linkEnd}.',
    ),
    link: helpPagePath('user/application_security/policies/merge_request_approval_policies', {
      anchor: 'merge-request-approval-policies-schema',
    }),
  },
  [POLICY_TYPE_FILTER_OPTIONS.SCAN_EXECUTION.text]: {
    content: s__(
      'SecurityOrchestration|Policy contains %{linkStart}deprecated syntax%{linkEnd} (%{deprecatedProperties}).',
    ),
    link: helpPagePath('user/application_security/policies/scan_execution_policies', {
      anchor: 'scan-execution-policies-schema',
    }),
  },
  exceedingAction: {
    content: s__(
      'SecurityOrchestration|Scan actions exceed the limit of %{maxScanExecutionPolicyActions} actions per policy.',
    ),
    link: helpPagePath('user/application_security/policies/scan_execution_policies', {
      anchor: 'scan-execution-policies-schema',
    }),
  },
  exceedingScheduledRules: {
    content: s__(
      'SecurityOrchestration|A scan execution policy exceeds the limit of %{maxScanExecutionPolicySchedules} scheduled rules per policy. Remove or consolidate rules across policies to reduce the total number of rules.',
    ),
    link: helpPagePath('user/application_security/policies/scan_execution_policies'),
  },
};

export const POLICIES_PER_PAGE = 50;
export const ACTION_LIMIT = 10;

export const TEST_RUN_STATES = {
  PENDING: 'PENDING',
  CREATING: 'CREATING',
  RUNNING: 'RUNNING',
  COMPLETE: 'COMPLETE',
  FAILED: 'FAILED',
};

export const TEST_RUN_STATE_CONFIG = {
  [TEST_RUN_STATES.PENDING]: {
    variant: 'neutral',
    icon: 'status_pending',
    text: s__('SecurityOrchestration|Test pending'),
  },
  [TEST_RUN_STATES.CREATING]: {
    variant: 'info',
    icon: 'status_pending',
    text: s__('SecurityOrchestration|Creating pipeline'),
  },
  [TEST_RUN_STATES.RUNNING]: {
    variant: 'info',
    icon: 'status_running',
    text: s__('SecurityOrchestration|Test running'),
  },
  [TEST_RUN_STATES.COMPLETE]: {
    variant: 'success',
    icon: 'status_closed',
    text: s__('SecurityOrchestration|Test complete'),
  },
  [TEST_RUN_STATES.FAILED]: {
    variant: 'danger',
    icon: 'status_failed',
    text: s__('SecurityOrchestration|Test failed'),
  },
};

export const DEFAULT_TEST_RUN_CONFIG = {
  variant: 'neutral',
  icon: null,
  text: '',
};
