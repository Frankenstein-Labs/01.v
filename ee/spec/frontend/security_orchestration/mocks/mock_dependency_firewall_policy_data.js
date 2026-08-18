import {
  MOCK_POLICY_CONFIGURATION_ID,
  POLICY_SCOPE_MOCK,
} from 'ee_jest/security_orchestration/mocks/mock_apollo';
import { DEPENDENCY_FIREWALL_POLICY_TYPE } from 'ee/security_orchestration/components/constants';

export const mockDependencyFirewallManifest = `name: Block known malicious packages
description: Blocks packages with known vulnerabilities from being installed
enabled: true
type: dependency_firewall_policy
`;

export const mockEnforcedDfwManifest = `name: Block Copyleft Licenses
description: Block packages with copyleft licenses
enabled: true
type: dependency_firewall_policy
enforcement_type: enforced
rules:
  - type: license
    denied:
      - name: GPL-3.0
      - name: AGPL-3.0
`;

export const mockEnforcedDfwPolicy = {
  name: 'Block Copyleft Licenses',
  yaml: mockEnforcedDfwManifest,
  ...POLICY_SCOPE_MOCK,
  type: DEPENDENCY_FIREWALL_POLICY_TYPE,
};

export const mockAdvisoryDfwManifest = `name: Advisory Policy
enabled: true
type: dependency_firewall_policy
enforcement_type: warn
rules:
  - type: license
    denied:
      - name: Apache-2.0
`;

export const mockAdvisoryDfwPolicy = {
  yaml: mockAdvisoryDfwManifest,
  ...POLICY_SCOPE_MOCK,
  type: DEPENDENCY_FIREWALL_POLICY_TYPE,
};

export const mockAllowedDfwManifest = `name: Allow Known Licenses
enabled: true
type: dependency_firewall_policy
rules:
  - type: license
    allowed:
      - name: MIT
`;

export const mockAllowedDfwPolicy = {
  yaml: mockAllowedDfwManifest,
  ...POLICY_SCOPE_MOCK,
  type: DEPENDENCY_FIREWALL_POLICY_TYPE,
};

export const mockEmptyRulesDfwManifest = `name: Empty Rules Policy
enabled: true
type: dependency_firewall_policy
rules: []
`;

export const mockEmptyRulesDfwPolicy = {
  yaml: mockEmptyRulesDfwManifest,
  ...POLICY_SCOPE_MOCK,
  type: DEPENDENCY_FIREWALL_POLICY_TYPE,
};

export const mockWithExceptionsDfwManifest = `name: Policy With Exceptions
enabled: true
type: dependency_firewall_policy
enforcement_type: enforced
rules:
  - type: license
    denied:
      - name: GPL-3.0
    exceptions:
      - purl: pkg:npm/known-gpl-package@1.0.0
      - purl: pkg:npm/another-exception@2.0.0
`;

export const mockWithExceptionsDfwPolicy = {
  yaml: mockWithExceptionsDfwManifest,
  ...POLICY_SCOPE_MOCK,
  type: DEPENDENCY_FIREWALL_POLICY_TYPE,
};

export const mockMultipleRulesDfwManifest = `name: Multiple Rules Policy
enabled: true
type: dependency_firewall_policy
enforcement_type: enforced
rules:
  - type: license
    denied:
      - name: GPL-3.0
  - type: license
    allowed:
      - name: MIT
      - name: Apache-2.0
`;

export const mockMultipleRulesDfwPolicy = {
  yaml: mockMultipleRulesDfwManifest,
  ...POLICY_SCOPE_MOCK,
  type: DEPENDENCY_FIREWALL_POLICY_TYPE,
};

export const mockProjectDependencyFirewallPolicyList = {
  __typename: 'DependencyFirewallPolicy',
  id: 'gid://gitlab/Security::DependencyFirewallPolicy/1',
  policyConfigurationId: MOCK_POLICY_CONFIGURATION_ID,
  csp: false,
  name: 'Block known malicious packages-project',
  policyAttributes: {
    __typename: 'DependencyFirewallPolicyAttributesType',
    source: {
      __typename: 'ProjectSecurityPolicySource',
      project: {
        fullPath: 'project/path',
      },
    },
  },
  updatedAt: new Date('2021-06-07T00:00:00.000Z'),
  yaml: mockDependencyFirewallManifest,
  editPath: '/policies/policy-name/edit?type="dependency_firewall_policy"',
  enabled: true,
  ...POLICY_SCOPE_MOCK,
  type: DEPENDENCY_FIREWALL_POLICY_TYPE,
};
