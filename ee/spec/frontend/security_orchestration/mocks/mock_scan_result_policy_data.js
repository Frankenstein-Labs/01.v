/**
 * Naming convention for mocks:
 * mock policy yaml => name ends in `ScanResultManifest`
 * mock parsed yaml => name ends in `ScanResultObject`
 * mock policy for list/drawer => name ends in `ScanResultPolicy`
 *
 * If you have the same policy in multiple forms (e.g. mock yaml and mock parsed yaml that should
 * match), please name them similarly (e.g. fooBarScanResultManifest and fooBarScanResultObject)
 * and keep them near each other.
 */
import { APPROVAL_POLICY_TYPE } from 'ee/security_orchestration/components/constants';
import {
  MOCK_POLICY_CONFIGURATION_ID,
  POLICY_SCOPE_MOCK,
} from 'ee_jest/security_orchestration/mocks/mock_apollo';
import { actionId, ruleId } from './mock_data';

export const zeroActionsScanResultManifest = `type: approval_policy
name: critical vulnerability CS approvals
description: This policy enforces critical vulnerability CS approvals
enabled: true
rules:
  - type: scan_finding
    branches: []
    scanners:
      - container_scanning
    vulnerabilities_allowed: 1
    severity_levels:
      - critical
    vulnerability_states:
      - newly_detected
`;

export const mockNoFallbackScanResultManifest = `type: approval_policy
name: critical vulnerability CS approvals
description: This policy enforces critical vulnerability CS approvals
enabled: true
rules:
  - type: scan_finding
    branches: []
    scanners:
      - container_scanning
    vulnerabilities_allowed: 1
    severity_levels:
      - critical
    vulnerability_states:
      - newly_detected
actions:
  - type: require_approval
    approvals_required: 1
    user_approvers:
      - the.one
  - type: send_bot_message
    enabled: true
`;

export const mockPolicyExceptionsScanResultManifest = `type: approval_policy
name: policy with bypass options
description: This policy enforces critical vulnerability CS approvals
enabled: true
rules:
  - type: scan_finding
    branches: []
    scanners:
      - container_scanning
    vulnerabilities_allowed: 1
    severity_levels:
      - critical
    vulnerability_states:
      - newly_detected
actions:
  - type: require_approval
    approvals_required: 1
    user_approvers:
      - the.one
  - type: send_bot_message
    enabled: true
bypass_settings:
  branches:
    - source:
        pattern: master
      target:
        name: '*test'
    - source:
        pattern: main
      target:
        name: '*test2'
`;

export const mockNoFallbackScanResultManifestNewFormat = `name: critical vulnerability CS approvals
description: This policy enforces critical vulnerability CS approvals
enabled: true
rules:
  - type: scan_finding
    branches: []
    scanners:
      - container_scanning
    vulnerabilities_allowed: 1
    severity_levels:
      - critical
    vulnerability_states:
      - newly_detected
actions:
  - type: require_approval
    approvals_required: 1
    user_approvers:
      - the.one
  - type: send_bot_message
    enabled: true
`;

export const mockDefaultBranchesScanResultManifest =
  mockNoFallbackScanResultManifest.concat(`fallback_behavior:
  fail: open
`);

export const mockDefaultBranchesScanResultManifestWithWrapper = `approval_policy:
  - name: critical vulnerability CS approvals
    description: This policy enforces critical vulnerability CS approvals
    enabled: true
    rules:
      - type: scan_finding
        branches: []
        scanners:
          - container_scanning
        vulnerabilities_allowed: 1
        severity_levels:
          - critical
        vulnerability_states:
          - newly_detected
    actions:
      - type: require_approval
        approvals_required: 1
        user_approvers:
          - the.one
      - type: send_bot_message
        enabled: true
    fallback_behavior:
      fail: open
`;

export const mockDefaultBranchesScanResultManifestNewFormat =
  mockNoFallbackScanResultManifestNewFormat.concat(`fallback_behavior:
  fail: open
`).concat(`type: approval_policy
`);

export const mockDefaultBranchesScanResultObject = {
  type: APPROVAL_POLICY_TYPE,
  name: 'critical vulnerability CS approvals',
  description: 'This policy enforces critical vulnerability CS approvals',
  enabled: true,
  rules: [
    {
      type: 'scan_finding',
      branches: [],
      scanners: ['container_scanning'],
      vulnerabilities_allowed: 1,
      severity_levels: ['critical'],
      vulnerability_states: ['newly_detected'],
      id: ruleId,
    },
  ],
  actions: [
    {
      type: 'require_approval',
      approvals_required: 1,
      user_approvers: ['the.one'],
      id: actionId,
    },
    { type: 'send_bot_message', enabled: true, id: `action_0` },
  ],
  fallback_behavior: {
    fail: 'open',
  },
};

export const mockWarnTypeScanResultManifest =
  mockDefaultBranchesScanResultManifest.concat(`enforcement_type: warn
`);

export const mockLegacyWarnTypeScanResultManifest = zeroActionsScanResultManifest.concat(`actions:
  - type: require_approval
    approvals_required: 0
    role_approvers:
      - owner
  - type: send_bot_message
    enabled: true
`);

export const mockLegacyWarnTypeScanResultObject = {
  ...mockDefaultBranchesScanResultObject,
  actions: [
    {
      type: 'require_approval',
      approvals_required: 0,
      id: actionId,
    },
    { type: 'send_bot_message', enabled: true, id: `action_0` },
  ],
};

export const mockDefaultBranchesScanResultObjectWithoutBotAction = {
  ...mockDefaultBranchesScanResultObject,
  actions: [
    {
      type: 'require_approval',
      approvals_required: 1,
      user_approvers: ['the.one'],
      id: actionId,
    },
  ],
};

export const mockDeprecatedScanResultManifest = `approval_policy:
  - name: critical vulnerability CS approvals
    description: This policy enforces critical vulnerability CS approvals
    enabled: true
    rules:
      - type: scan_finding
        branches: []
        scanners:
          - container_scanning
        vulnerabilities_allowed: 1
        severity_levels:
          - critical
        vulnerability_states:
          - newly_detected
    actions:
      - type: require_approval
        approvals_required: 1
        user_approvers:
          - the.one
    fallback_behavior:
      fail: open
`;

export const enabledSendBotMessageActionScanResultManifest = zeroActionsScanResultManifest.concat(`
actions:
  - type: send_bot_message
    enabled: true
`);

export const disabledSendBotMessageActionScanResultManifest = zeroActionsScanResultManifest.concat(`
actions:
  - type: send_bot_message
    enabled: false
`);

export const mockDeprecatedScanResultObject = {
  type: 'scan_result_policy',
  name: 'critical vulnerability CS approvals',
  description: 'This policy enforces critical vulnerability CS approvals',
  enabled: true,
  rules: [
    {
      type: 'scan_finding',
      branches: [],
      scanners: ['container_scanning'],
      vulnerabilities_allowed: 1,
      severity_levels: ['critical'],
      vulnerability_states: ['newly_detected'],
      id: ruleId,
    },
  ],
  actions: [
    {
      type: 'require_approval',
      approvals_required: 1,
      user_approvers: ['the.one'],
      id: actionId,
    },
  ],
};

export const mockProjectScanResultPolicy = {
  __typename: 'ScanResultPolicy',
  id: 'gid://gitlab/Security::ApprovalPolicy/1',
  csp: false,
  name: `${mockDefaultBranchesScanResultObject.name}-project`,
  updatedAt: new Date('2021-06-07T00:00:00.000Z'),
  yaml: mockDefaultBranchesScanResultManifest,
  deprecatedProperties: [],
  editPath: '/policies/policy-name/edit?type="approval_policy"',
  enabled: false,
  actionApprovers: [],
  ...POLICY_SCOPE_MOCK,
  source: {
    __typename: 'ProjectSecurityPolicySource',
    project: {
      fullPath: 'project/path',
    },
  },
};

export const mockProjectScanResultPolicyList = {
  __typename: 'ScanResultPolicy',
  id: 'gid://gitlab/Security::ApprovalPolicy/1',
  policyConfigurationId: MOCK_POLICY_CONFIGURATION_ID,
  csp: false,
  policyAttributes: {
    __typename: 'ApprovalPolicyAttributesType',
    deprecatedProperties: [],
    source: {
      __typename: 'ProjectSecurityPolicySource',
      project: {
        fullPath: 'project/path',
      },
    },
  },
  name: `${mockDefaultBranchesScanResultObject.name}-project`,
  updatedAt: new Date('2021-06-07T00:00:00.000Z'),
  yaml: mockDefaultBranchesScanResultManifest,
  deprecatedProperties: [],
  editPath: '/policies/policy-name/edit?type="approval_policy"',
  enabled: false,
  type: APPROVAL_POLICY_TYPE,
  ...POLICY_SCOPE_MOCK,
  source: {
    __typename: 'ProjectSecurityPolicySource',
    project: {
      fullPath: 'project/path',
    },
  },
};

export const mockGroupScanResultPolicy = {
  __typename: 'ScanResultPolicy',
  id: 'gid://gitlab/Security::ApprovalPolicy/2',
  csp: false,
  name: `${mockDefaultBranchesScanResultObject.name}-group`,
  updatedAt: new Date('2021-06-07T00:00:00.000Z'),
  yaml: mockDefaultBranchesScanResultManifest,
  deprecatedProperties: [],
  editPath: '/policies/policy-name/edit?type="approval_policy"',
  enabled: mockDefaultBranchesScanResultObject.enabled,
  actionApprovers: [],
  ...POLICY_SCOPE_MOCK,
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

export const mockGroupScanResultPolicyList = {
  __typename: 'ScanResultPolicy',
  id: 'gid://gitlab/Security::ApprovalPolicy/2',
  policyConfigurationId: MOCK_POLICY_CONFIGURATION_ID,
  csp: false,
  name: `${mockDefaultBranchesScanResultObject.name}-group`,
  policyAttributes: {
    __typename: 'ApprovalPolicyAttributesType',
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
  updatedAt: new Date('2021-06-07T00:00:00.000Z'),
  yaml: mockDefaultBranchesScanResultManifest,
  deprecatedProperties: [],
  editPath: '/policies/policy-name/edit?type="approval_policy"',
  enabled: mockDefaultBranchesScanResultObject.enabled,
  ...POLICY_SCOPE_MOCK,
  type: APPROVAL_POLICY_TYPE,
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

export const mockApprovalSettingsPermittedInvalidScanResultManifest =
  mockNoFallbackScanResultManifest
    .concat(
      `
approval_settings:
  block_protected_branch_modification:
    enabled: true
`,
    )
    .concat('fallback_behavior:\n  fail: open');

export const mockApprovalSettingsScanResultObject = {
  ...mockDefaultBranchesScanResultObject,
  approval_settings: {
    block_branch_modification: true,
    prevent_pushing_and_force_pushing: true,
    prevent_approval_by_author: true,
  },
};

export const mockDisabledApprovalSettingsScanResultObject = {
  ...mockDefaultBranchesScanResultObject,
  approval_settings: {
    block_branch_modification: false,
    prevent_pushing_and_force_pushing: false,
    block_group_branch_modification: false,
  },
};

export const mockApprovalSettingsPermittedInvalidScanResultObject = {
  ...mockDefaultBranchesScanResultObject,
  approval_settings: {
    block_protected_branch_modification: {
      enabled: true,
    },
  },
  fallback_behavior: { fail: 'open' },
};

export const allowDenyScanResultLicenseNonEmptyManifest = `---
name: This policy has license packages with exceptions
description: This policy license packages with exceptions
enabled: true
rules:
  - type: license_finding
    match_on_inclusion_license: true
    license_types: ['MIT']
    license_states:
      - detected
    branch_type: protected
    licenses:
      allowed:
        - name: MIT
          packages: []
        - name: NPM
          packages:
            excluding:
              purls:
                - pkg:npm40angular/animation
                - pkg:npm40angular/animation@12.3.1
actions:
  - type: require_approval
    approvals_required: 1
`;

export const denyScanResultLicenseNonEmptyManifest =
  allowDenyScanResultLicenseNonEmptyManifest.replace('allowed', 'denied');

export const licenseOverridesScanResultManifest = `---
name: Policy with license overrides
description: ''
enabled: true
rules:
  - type: license_finding
    match_on_inclusion_license: true
    license_types: ['MIT']
    license_states:
      - detected
    branch_type: protected
    license_overrides:
      - purl: pkg:pypi/urllib3
        license: MIT License
        mode: patch
      - purl: pkg:gem/rails
        license: Apache-2.0
        mode: overwrite
actions:
  - type: require_approval
    approvals_required: 1
`;

export const mockWithBranchesScanResultManifest = `type: approval_policy
name: low vulnerability SAST approvals
description: This policy enforces low vulnerability SAST approvals
enabled: true
rules:
  - type: scan_finding
    branches:
      - main
    scanners:
      - sast
    vulnerabilities_allowed: 1
    severity_levels:
      - low
    vulnerability_states:
      - newly_detected
actions:
  - type: require_approval
    approvals_required: 1
    user_approvers:
      - the.one
`;

export const mockProjectWithBranchesScanResultPolicy = {
  __typename: 'ScanResultPolicy',
  csp: false,
  name: 'low vulnerability SAST approvals',
  updatedAt: new Date('2021-06-07T00:00:00.000Z'),
  yaml: mockWithBranchesScanResultManifest,
  editPath: '/policies/policy-name/edit?type="approval_policy"',
  enabled: true,
  actionApprovers: [],
  userApprovers: [{ name: 'the.one' }],
  allGroupApprovers: [],
  roleApprovers: [],
  source: {
    __typename: 'ProjectSecurityPolicySource',
    project: {
      fullPath: 'project/path/second',
    },
  },
};

export const mockProjectWithAllApproverTypesScanResultPolicy = {
  __typename: 'ScanResultPolicy',
  csp: false,
  name: mockDefaultBranchesScanResultObject.name,
  updatedAt: new Date('2021-06-07T00:00:00.000Z'),
  yaml: mockDefaultBranchesScanResultManifest,
  editPath: '/policies/policy-name/edit?type="approval_policy"',
  enabled: false,
  actionApprovers: [
    {
      users: [{ name: 'the.one' }],
      allGroups: [{ fullPath: 'the.one.group' }],
      roles: ['OWNER'],
    },
  ],
  source: {
    __typename: 'ProjectSecurityPolicySource',
    project: {
      fullPath: 'project/path',
    },
  },
};

export const mockProjectFallbackClosedScanResultManifest =
  mockDefaultBranchesScanResultManifest.concat(`fallback_behavior:\n  fail: closed`);

export const mockProjectPolicyTuningScanResultManifest =
  mockDefaultBranchesScanResultManifest.concat(
    `policy_tuning:\n  unblock_rules_using_execution_policies: true`,
  );

export const mockInvalidRulesScanResultManifest = `type: approval_policy
name: critical vulnerability CS approvals
description: This policy enforces critical vulnerability CS approvals
enabled: true
rules:
  - type: scan_finding
    branches: []
    scanners:
      - fake_container_scanning
    vulnerabilities_allowed: 1
    severity_levels:
      - critical
    vulnerability_states:
      - newly_detected
actions: []
`;

export const mockInvalidApprovalSettingScanResultManifest = mockDefaultBranchesScanResultManifest
  .concat(`approval_settings:\n  fake_block_branch_modification: true\n`)
  .concat(`fallback_behavior:\n  fail: open`);

export const mockInvalidGroupApprovalSettingStructureScanResultManifest =
  mockDefaultBranchesScanResultManifest
    .concat(`approval_settings:\n  prevent_pushing_and_force_pushing:\n   []\n`)
    .concat(`fallback_behavior:\n  fail: open`);

export const mockProjectApprovalSettingsScanResultManifest = mockDefaultBranchesScanResultManifest
  .concat(
    `
approval_settings:
  block_branch_modification: true
  prevent_pushing_and_force_pushing: true
  prevent_approval_by_author: true
`,
  )
  .concat(`fallback_behavior:\n  fail: open`);

export const mockGroupApprovalSettingsScanResultManifest = mockDefaultBranchesScanResultManifest
  .concat(
    `
approval_settings:
  block_branch_modification: true
  block_group_branch_modification:
    enabled: true
    exceptions:
      - release/*
  prevent_pushing_and_force_pushing: true
`,
  )
  .concat(`fallback_behavior:\n  fail: open`);

export const mockGroupApprovalSettingsScanResultObject = {
  ...mockDefaultBranchesScanResultObject,
  approval_settings: {
    block_branch_modification: true,
    block_group_branch_modification: {
      enabled: true,
      exceptions: ['release/*'],
    },
    prevent_pushing_and_force_pushing: true,
  },
};

const defaultScanResultPolicy = {
  __typename: 'ScanResultPolicy',
  csp: false,
  updatedAt: new Date('2021-06-07T00:00:00.000Z'),
  editPath: '/policies/policy-name/edit?type="approval_policy"',
  enabled: true,
  userApprovers: [{ name: 'the.one' }],
  allGroupApprovers: [],
  roleApprovers: [],
  source: {
    __typename: 'ProjectSecurityPolicySource',
    project: {
      fullPath: 'project/path/second',
    },
  },
};

export const mockProjectApprovalSettingsScanResultPolicy = {
  ...defaultScanResultPolicy,
  name: 'low vulnerability SAST approvals',
  yaml: mockProjectApprovalSettingsScanResultManifest,
  approval_settings: {
    block_branch_modification: true,
    prevent_pushing_and_force_pushing: true,
    prevent_approval_by_author: true,
  },
};

export const mockScanResultPoliciesResponse = [
  mockProjectScanResultPolicy,
  mockGroupScanResultPolicy,
];

export const createApprovers = ({
  group = false,
  user = false,
  role = false,
  customRole = false,
}) => {
  const mockUser = {
    webUrl: `webUrl1`,
    __typename: 'UserCore',
    name: `username1`,
    id: `gid://gitlab/User/1`,
  };

  const mockGroup = {
    webUrl: `webUrl2`,
    __typename: 'Group',
    fullPath: `grouppath2`,
    id: `gid://gitlab/Group/2`,
  };

  const mockCustomRole = {
    __typename: 'MemberRole',
    name: `Custom`,
    id: `gid://gitlab/MemberRole/3`,
  };

  return []
    .concat(group ? mockGroup : [])
    .concat(user ? mockUser : [])
    .concat(role ? 'Owner' : [])
    .concat(customRole ? mockCustomRole : []);
};

export const mockFallbackInvalidScanResultManifest = mockDefaultBranchesScanResultManifest.concat(
  `fallback_behavior:\n  fail: something_else`,
);
