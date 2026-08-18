import {
  createPolicyObject,
  DEFAULT_SCAN_RESULT_POLICY,
  DEFAULT_SCAN_RESULT_POLICY_WITH_SCOPE_WITH_GROUP_SETTINGS,
  getPolicyYaml,
  policyToYaml,
} from 'ee/security_orchestration/components/policy_editor/scan_result/lib';
import { isGroup } from 'ee/security_orchestration/components/utils';
import { NAMESPACE_TYPES } from 'ee/security_orchestration/constants';

describe('getPolicyYaml', () => {
  it.each`
    namespaceType              | expected
    ${NAMESPACE_TYPES.PROJECT} | ${DEFAULT_SCAN_RESULT_POLICY}
    ${NAMESPACE_TYPES.GROUP}   | ${DEFAULT_SCAN_RESULT_POLICY_WITH_SCOPE_WITH_GROUP_SETTINGS}
  `('returns the yaml for the $namespaceType namespace', ({ namespaceType, expected }) => {
    expect(getPolicyYaml({ isGroup: isGroup(namespaceType) })).toEqual(expected);
  });
});

describe('is_malicious YAML round-trip', () => {
  const buildPolicy = (scanner) => ({
    type: 'approval_policy',
    name: 'Malware policy',
    enabled: true,
    rules: [
      {
        type: 'scan_finding',
        branch_type: 'protected',
        scanners: [scanner],
        vulnerabilities_allowed: 0,
        severity_levels: ['critical'],
        vulnerability_states: ['new_needs_triage'],
      },
    ],
    actions: [{ type: 'require_approval', approvals_required: 1, role_approvers: ['maintainer'] }],
  });

  const getScanner = (policy) => policy.rules[0].scanners[0];

  it.each(['dependency_scanning', 'container_scanning'])(
    'preserves is_malicious=true for %s through serialize and parse',
    (scannerType) => {
      const manifest = policyToYaml(
        buildPolicy({ type: scannerType, vulnerabilities_allowed: 0, is_malicious: true }),
      );

      expect(manifest).toContain('is_malicious: true');

      const { policy, parsingError } = createPolicyObject(manifest);

      expect(parsingError).toEqual({});
      expect(getScanner(policy)).toMatchObject({ type: scannerType, is_malicious: true });
    },
  );

  it('does not add is_malicious when it is absent from the policy', () => {
    const manifest = policyToYaml(
      buildPolicy({ type: 'dependency_scanning', vulnerabilities_allowed: 0 }),
    );

    expect(manifest).not.toContain('is_malicious');

    const { policy, parsingError } = createPolicyObject(manifest);

    expect(parsingError).toEqual({});
    expect(getScanner(policy)).not.toHaveProperty('is_malicious');
  });
});
