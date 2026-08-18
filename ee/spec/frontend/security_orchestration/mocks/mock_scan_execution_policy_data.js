import { STRATEGIES_RULE_MAP } from 'ee/security_orchestration/components/policy_editor/scan_execution/lib';
import { SCAN_EXECUTION_POLICY_TYPE } from 'ee/security_orchestration/components/constants';
import {
  MOCK_POLICY_CONFIGURATION_ID,
  POLICY_SCOPE_MOCK,
} from 'ee_jest/security_orchestration/mocks/mock_apollo';
import { actionId, ruleId, unsupportedManifest, unsupportedManifestObject } from './mock_data';

export const customYaml = `variable: true
`;

export const customYamlObject = { variable: true };

export const mockUnsupportedAttributeScanExecutionPolicy = {
  __typename: 'ScanExecutionPolicy',
  id: 'gid://gitlab/Security::ScanExecutionPolicy/0',
  csp: false,
  name: unsupportedManifestObject.name,
  updatedAt: new Date('2021-06-07T00:00:00.000Z'),
  yaml: unsupportedManifest,
  enabled: false,
  source: {
    __typename: 'ProjectSecurityPolicySource',
  },
};

const defaultMockScanExecutionManifest = `type: scan_execution_policy
name: Scheduled Dast/SAST scan
description: This policy enforces pipeline configuration to have a job with DAST scan
enabled: false`;

export const defaultMockScanExecutionObject = {
  type: SCAN_EXECUTION_POLICY_TYPE,
  name: 'Scheduled Dast/SAST scan',
  description: 'This policy enforces pipeline configuration to have a job with DAST scan',
  enabled: false,
};

export const mockScanExecutionPolicyManifestWithWrapper = `scan_execution_policy:
  - name: Scheduled Dast/SAST scan
    description: This policy enforces pipeline configuration to have a job with DAST scan
    enabled: true
    rules:
      - type: pipeline
        branches:
          - '*'
    actions:
      - scan: secret_detection
`;

export const mockScanExecutionWithConfigurationManifest = `scan_execution_policy:
  - name: Scheduled Dast/SAST scan
    description: This policy enforces pipeline configuration to have a job with DAST scan
    enabled: true
    rules:
      - type: pipeline
        branches:
          - '*'
    actions:
      - scan: secret_detection
    skip_ci:
      allowed: true
`;

export const mockCustomScanExecutionManifest = `scan_execution_policy:
  - name: ''
    description: ''
    enabled: true
    rules:
      - type: pipeline
        branches:
          - '*'
    actions:
      - scan: secret_detection
    skip_ci:
      allowed: true
`;

export const mockCustomScanExecutionObject = {
  type: SCAN_EXECUTION_POLICY_TYPE,
  name: '',
  description: '',
  enabled: true,
  rules: [{ type: 'pipeline', branches: ['*'] }],
  actions: [{ scan: 'secret_detection' }],
  skip_ci: { allowed: true },
};

export const mockCustomScanExecutionWithDefaultVariablesManifest = `scan_execution_policy:
  - name: ''
    description: ''
    enabled: true
    rules:
      - type: pipeline
        branches:
          - '*'
    actions:
      - scan: secret_detection
        variables:
          SECURE_ENABLE_LOCAL_CONFIGURATION: 'false'
    skip_ci:
      allowed: true
`;

export const mockScanExecutionWithDefaultVariablesManifest = `scan_execution_policy:
  - name: ''
    description: ''
    enabled: true
    policy_scope:
      projects:
        excluding: []
    rules:
      - type: pipeline
        branch_type: default
      - type: pipeline
        branch_type: target_default
        pipeline_sources:
          including:
            - merge_request_event
    actions:
      - scan: secret_detection
        template: latest
        variables:
          SECURE_ENABLE_LOCAL_CONFIGURATION: 'false'
    skip_ci:
      allowed: true
`;

export const mockScheduleScanExecutionManifest = defaultMockScanExecutionManifest.concat(`
rules:
  - type: schedule
    cadence: '* * * * *'
    branches:
      - main
  - type: pipeline
    branches:
      - main
actions:
  - scan: secret_detection
`);

export const mockMultipleScheduleScanExecutionManifest = defaultMockScanExecutionManifest.concat(`
rules:
  - type: schedule
    cadence: '* * * * *'
    branches:
      - main
  - type: schedule
    cadence: '* * * * *'
    branches:
      - main
  - type: pipeline
    branches:
      - main
actions:
  - scan: secret_detection
`);

export const mockScheduleScanExecutionObject = {
  ...defaultMockScanExecutionObject,
  rules: [
    { type: 'schedule', cadence: '* * * * *', branches: ['main'], id: ruleId },
    { type: 'pipeline', branches: ['main'], id: ruleId },
  ],
  actions: [
    {
      scan: 'secret_detection',
      id: actionId,
    },
  ],
};

export const mockScheduledTemplateScanExecutionObject = {
  ...defaultMockScanExecutionObject,
  rules: [...STRATEGIES_RULE_MAP.scheduled],
  actions: [{ scan: 'secret_detection', template: 'latest' }],
};

export const mockDastScanExecutionManifest = `name: Scheduled Dast/SAST scan
description: This policy enforces pipeline configuration to have a job with DAST scan
enabled: false
rules:
  - type: pipeline
    branches:
      - main
actions:
  - scan: dast
    site_profile: required_site_profile
    scanner_profile: required_scanner_profile
type: scan_execution_policy
`;

export const mockDastScanExecutionManifestWithoutType = (type) => `${type}:
  - name: Scheduled Dast/SAST scan
    description: This policy enforces pipeline configuration to have a job with DAST scan
    enabled: false
    rules:
      - type: pipeline
        branches:
          - main
    actions:
      - scan: dast
        site_profile: required_site_profile
        scanner_profile: required_scanner_profile
`;

export const mockDastScanExecutionObject = {
  ...mockScheduleScanExecutionObject,
  rules: [{ type: 'pipeline', branches: ['main'], id: ruleId }],
  actions: [
    {
      scan: 'dast',
      site_profile: 'required_site_profile',
      scanner_profile: 'required_scanner_profile',
      id: actionId,
    },
  ],
};

export const mockBranchExceptionsExecutionManifest = `type: scan_execution_policy
name: Branch exceptions
description: This policy enforces pipeline configuration to have branch exceptions
enabled: false
rules:
  - type: pipeline
    branches:
      - main
    branch_exceptions:
      - main
      - test
actions:
  - scan: dast
    site_profile: required_site_profile
    scanner_profile: required_scanner_profile
`;

export const mockBranchExceptionsScanExecutionObject = {
  type: SCAN_EXECUTION_POLICY_TYPE,
  name: 'Branch exceptions',
  description: 'This policy enforces pipeline configuration to have branch exceptions',
  enabled: false,
  rules: [
    { type: 'pipeline', branches: ['main'], branch_exceptions: ['main', 'test'], id: ruleId },
  ],
  actions: [
    {
      scan: 'dast',
      site_profile: 'required_site_profile',
      scanner_profile: 'required_scanner_profile',
      id: actionId,
    },
  ],
};

export const mockProjectScanExecutionPolicy = {
  __typename: 'ScanExecutionPolicy',
  id: 'gid://gitlab/Security::ScanExecutionPolicy/1',
  csp: false,
  name: `${mockDastScanExecutionObject.name}-project`,
  updatedAt: new Date('2021-06-07T00:00:00.000Z'),
  yaml: mockDastScanExecutionManifest,
  type: SCAN_EXECUTION_POLICY_TYPE,
  policyAttributes: {
    __typename: 'ScanExecutionPolicyAttributesType',
    deprecatedProperties: [],
    source: {
      __typename: 'ProjectSecurityPolicySource',
      project: {
        fullPath: 'project/path',
      },
    },
  },
  editPath: '/policies/policy-name/edit?type="scan_execution_policy"',
  enabled: true,
  ...POLICY_SCOPE_MOCK,
  deprecatedProperties: [],
};

export const mockProjectScanExecutionPolicyList = {
  __typename: 'ScanExecutionPolicy',
  id: 'gid://gitlab/Security::ScanExecutionPolicy/1',
  policyConfigurationId: MOCK_POLICY_CONFIGURATION_ID,
  csp: false,
  name: `${mockDastScanExecutionObject.name}-project`,
  policyAttributes: {
    __typename: 'ScanExecutionPolicyAttributesType',
    deprecatedProperties: [],
    source: {
      __typename: 'ProjectSecurityPolicySource',
      project: {
        fullPath: 'project/path',
      },
    },
  },
  updatedAt: new Date('2021-06-07T00:00:00.000Z'),
  yaml: mockDastScanExecutionManifest,
  editPath: '/policies/policy-name/edit?type="scan_execution_policy"',
  enabled: true,
  ...POLICY_SCOPE_MOCK,
  type: SCAN_EXECUTION_POLICY_TYPE,
  deprecatedProperties: [],
  source: {
    __typename: 'ProjectSecurityPolicySource',
    project: {
      fullPath: 'project/path',
    },
  },
};

export const mockProjectScanExecutionPolicyWithWrapper = {
  ...mockProjectScanExecutionPolicy,
  yaml: mockScanExecutionPolicyManifestWithWrapper,
};

export const mockProjectScanExecutionWithConfigurationPolicy = {
  ...mockProjectScanExecutionPolicy,
  yaml: mockScanExecutionWithConfigurationManifest,
};

export const mockScheduledProjectScanExecutionPolicy = {
  ...mockProjectScanExecutionPolicy,
  yaml: mockMultipleScheduleScanExecutionManifest,
};

export const mockBranchExceptionsProjectScanExecutionPolicy = {
  ...mockProjectScanExecutionPolicy,
  yaml: mockBranchExceptionsExecutionManifest,
};

export const mockGroupScanExecutionPolicy = {
  ...mockProjectScanExecutionPolicy,
  name: `${mockDastScanExecutionObject.name}-group`,
  enabled: false,
  source: {
    __typename: 'GroupSecurityPolicySource',
    inherited: true,
    namespace: {
      __typename: 'Namespace',
      id: '1',
      fullPath: 'parent-group-path',
      name: 'parent-group-name',
    },
  },
};

export const mockGroupScanExecutionPolicyList = {
  ...mockProjectScanExecutionPolicy,
  policyConfigurationId: MOCK_POLICY_CONFIGURATION_ID,
  policyAttributes: {
    __typename: 'ScanExecutionPolicyAttributesType',
    deprecatedProperties: [],
    source: {
      __typename: 'GroupSecurityPolicySource',
      inherited: true,
      namespace: {
        __typename: 'Namespace',
        id: '1',
        fullPath: 'parent-group-path',
        name: 'parent-group-name',
      },
    },
  },
  name: `${mockDastScanExecutionObject.name}-group`,
  enabled: false,
  deprecatedProperties: [],
  source: {
    __typename: 'GroupSecurityPolicySource',
    inherited: true,
    namespace: {
      __typename: 'Namespace',
      id: '1',
      fullPath: 'parent-group-path',
      name: 'parent-group-name',
    },
  },
};

export const mockScanExecutionPoliciesResponse = [
  mockProjectScanExecutionPolicy,
  mockGroupScanExecutionPolicy,
];

export const mockScanExecutionPoliciesWithSameNamesDifferentSourcesResponse = [
  mockProjectScanExecutionPolicy,
  {
    ...mockProjectScanExecutionPolicy,
    policyConfigurationId: 'gid://gitlab/Security::OrchestrationPolicyConfiguration/2',
    updatedAt: new Date('2021-06-09T00:00:00.000Z').getDate(),
    policyAttributes: {
      __typename: 'ScanExecutionPolicyAttributesType',
      deprecatedProperties: [],
      source: {
        __typename: 'GroupSecurityPolicySource',
        inherited: true,
        namespace: {
          __typename: 'Namespace',
          id: '1',
          fullPath: 'parent-group-path',
          name: 'parent-group-name',
        },
      },
    },
  },
];

export const mockScheduleScanExecutionPoliciesResponse = [
  mockScheduledProjectScanExecutionPolicy,
  ...mockScanExecutionPoliciesResponse,
];

export const mockCiVariablesWithTagsScanExecutionManifest = `---
name: Enforce Secret Detection in every pipeline
enabled: true
rules:
- type: pipeline
  branches:
  - main
actions:
- scan: secret_detection
  tags:
  - default
  variables:
    SECRET_DETECTION_HISTORIC_SCAN: 'true'
`;

export const mockNoActionsScanExecutionManifest = `type: scan_execution_policy
name: Test Dast
description: This policy enforces pipeline configuration to have a job with DAST scan
enabled: false
rules:
  - type: pipeline
    branches:
      - main
actions: []
`;

export const mockMultipleActionsScanExecutionManifest = `type: scan_execution_policy
name: Test Dast
description: This policy enforces pipeline configuration to have a job with DAST scan
enabled: false
rules:
  - type: pipeline
    branches:
      - main
actions:
  - scan: container_scanning
  - scan: secret_detection
  - scan: sast
`;

export const mockInvalidCadenceScanExecutionManifest = `type: scan_execution_policy
name: This policy has an invalid cadence
description: ''
enabled: false
rules:
- type: schedule
  cadence: INVALID * * * *
  branches:
  - main
actions:
- scan: sast
`;

export const mockInvalidCadenceScanExecutionObject = {
  type: SCAN_EXECUTION_POLICY_TYPE,
  name: 'This policy has an invalid cadence',
  description: '',
  enabled: false,
  rules: [{ type: 'schedule', branches: ['main'], cadence: 'INVALID * * * *', id: ruleId }],
  actions: [{ scan: 'sast', id: actionId }],
};

export const mockTemplateScanExecutionObject = {
  ...mockDastScanExecutionObject,
  actions: [{ ...mockDastScanExecutionObject.actions[0], template: 'default' }],
};

export const mockInvalidTemplateScanExecutionManifest = `scan_execution_policy:
name: Scheduled Dast/SAST scan
description: This policy enforces pipeline configuration to have a job with DAST scan
enabled: false
rules:
  - type: pipeline
    branches:
      - main
actions:
  - scan: dast
    site_profile: required_site_profile
    scanner_profile: required_scanner_profile
    template: not-valid-value
`;

export const mockInvalidActionScanExecutionObject = {
  ...mockDastScanExecutionObject,
  actions: [{ scan: 'sastt', id: actionId }],
};

export const mockInvalidRuleScanExecutionObject = {
  ...mockDastScanExecutionObject,
  rules: [{ type: 'pipeline', branch_type: '', branches: ['main'], id: ruleId }],
};

export const mockInvalidTemplateScanExecutionObject = {
  ...mockDastScanExecutionObject,
  actions: [
    {
      id: actionId,
      scan: 'dast',
      scanner_profile: 'required_scanner_profile',
      site_profile: 'required_site_profile',
      template: 'not-valid-value',
    },
  ],
};

export const mockScanSettingsScanExecutionManifest = mockScheduleScanExecutionManifest.concat(
  `    scan_settings:\n      ignore_default_before_after_script: true`,
);

export const mockScanSettingsScanExecutionObject = {
  ...mockScheduleScanExecutionObject,
  actions: [
    {
      ...mockScheduleScanExecutionObject.actions[0],
      scan_settings: { ignore_default_before_after_script: true },
    },
  ],
};
