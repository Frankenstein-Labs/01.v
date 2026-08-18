import {
  DEFAULT_SCAN_RESULT_POLICY,
  createPolicyObject,
  validatePolicy,
  hasRequireApprovalAction,
  hasRules,
  hasSettings,
  hasEnabledProjectSettings,
  getSettingAlertConfig,
} from 'ee/security_orchestration/components/policy_editor/scan_result/lib';
import {
  mockDefaultBranchesScanResultManifest,
  mockDefaultBranchesScanResultObject,
  mockApprovalSettingsPermittedInvalidScanResultManifest,
  mockFallbackInvalidScanResultManifest,
  mockInvalidRulesScanResultManifest,
  mockInvalidApprovalSettingScanResultManifest,
  mockInvalidGroupApprovalSettingStructureScanResultManifest,
} from 'ee_jest/security_orchestration/mocks/mock_scan_result_policy_data';
import {
  invalidYaml,
  unsupportedManifest,
  unsupportedManifestObject,
} from 'ee_jest/security_orchestration/mocks/mock_data';
import { APPROVAL_POLICY_TYPE } from 'ee/security_orchestration/components/constants';
import { fromYaml } from 'ee/security_orchestration/components/utils';

jest.mock('lodash-es', () => ({
  ...jest.requireActual('lodash-es'),
  uniqueId: jest.fn((prefix) => `${prefix}0`),
}));

describe('createPolicyObject', () => {
  it.each`
    title                                                                           | input                                    | output
    ${'returns the policy object and no errors for a supported manifest'}           | ${mockDefaultBranchesScanResultManifest} | ${{ policy: mockDefaultBranchesScanResultObject, parsingError: {} }}
    ${'returns the error policy object and the error for an unsupported manifest'}  | ${unsupportedManifest}                   | ${{ policy: { ...unsupportedManifestObject, type: 'approval_policy' }, parsingError: {} }}
    ${'returns the error policy object and the error for an invalid strategy name'} | ${invalidYaml}                           | ${{ policy: {}, parsingError: { actions: true, fallback: true, rules: true, settings: true } }}
  `('$title', ({ input, output }) => {
    expect(createPolicyObject(input)).toStrictEqual(output);
  });
});

describe('validatePolicy', () => {
  it.each`
    title                                                                                    | input                                                         | output
    ${'returns empty object when there are no errors'}                                       | ${DEFAULT_SCAN_RESULT_POLICY}                                 | ${{}}
    ${'returns empty object with `approval_settings` containing permitted invalid settings'} | ${mockApprovalSettingsPermittedInvalidScanResultManifest}     | ${{}}
    ${'returns error objects for invalid content'}                                           | ${invalidYaml}                                                | ${{ actions: true, fallback: true, rules: true, settings: true }}
    ${'returns error objects for an invalid fallback value'}                                 | ${mockFallbackInvalidScanResultManifest}                      | ${{ fallback: true }}
    ${'returns error objects for an empty policy'}                                           | ${''}                                                         | ${{ actions: true, fallback: true, rules: true, settings: true }}
    ${'returns error objects for invalid rules'}                                             | ${mockInvalidRulesScanResultManifest}                         | ${{ rules: true }}
    ${'returns error objects for invalid settings'}                                          | ${mockInvalidApprovalSettingScanResultManifest}               | ${{ settings: true }}
    ${'returns error objects for invalid setting structure'}                                 | ${mockInvalidGroupApprovalSettingStructureScanResultManifest} | ${{ settings: true }}
  `('$title', ({ input, output }) => {
    expect(
      validatePolicy(
        fromYaml({
          manifest: input,
          type: APPROVAL_POLICY_TYPE,
          addIds: true,
        }),
      ),
    ).toStrictEqual(output);
  });
});

describe('hasRequireApprovalAction', () => {
  it.each`
    actions                                                         | expected
    ${undefined}                                                    | ${false}
    ${[]}                                                           | ${false}
    ${[{ type: 'send_bot_message' }]}                               | ${false}
    ${[{ type: 'require_approval' }]}                               | ${true}
    ${[{ type: 'send_bot_message' }, { type: 'require_approval' }]} | ${true}
  `('returns $expected for $actions', ({ actions, expected }) => {
    expect(hasRequireApprovalAction(actions)).toBe(expected);
  });
});

describe('hasRules', () => {
  it.each`
    rules                         | expected
    ${undefined}                  | ${false}
    ${[]}                         | ${false}
    ${[{ type: '' }]}             | ${false}
    ${[{ type: 'scan_finding' }]} | ${true}
  `('returns $expected for $rules', ({ rules, expected }) => {
    expect(hasRules(rules)).toBe(expected);
  });
});

describe('hasSettings', () => {
  it.each`
    settings                                                      | expected
    ${undefined}                                                  | ${false}
    ${{}}                                                         | ${false}
    ${{ prevent_approval_by_author: false }}                      | ${false}
    ${{ block_protected_branch_modification: { enabled: true } }} | ${false}
    ${{ prevent_approval_by_author: true }}                       | ${true}
    ${{ block_group_branch_modification: { enabled: true } }}     | ${true}
    ${{ block_group_branch_modification: { enabled: false } }}    | ${false}
    ${{ block_group_branch_modification: null }}                  | ${false}
    ${{ block_group_branch_modification: undefined }}             | ${false}
    ${{ block_group_branch_modification: {} }}                    | ${false}
  `('returns $expected for $settings', ({ settings, expected }) => {
    expect(hasSettings(settings)).toBe(expected);
  });
});

describe('hasEnabledProjectSettings', () => {
  it.each`
    settings                                      | expected
    ${undefined}                                  | ${false}
    ${{}}                                         | ${false}
    ${{ block_branch_modification: true }}        | ${false}
    ${{ prevent_approval_by_author: false }}      | ${false}
    ${{ prevent_approval_by_author: true }}       | ${true}
    ${{ remove_approvals_with_new_commit: true }} | ${true}
    ${{ prevent_editing_approval_rules: true }}   | ${true}
    ${{ prevent_editing_approval_rules: false }}  | ${false}
  `('returns $expected for $settings', ({ settings, expected }) => {
    expect(hasEnabledProjectSettings(settings)).toBe(expected);
  });
});

describe('getSettingAlertConfig', () => {
  it('returns show: false when there are non-action parsing errors', () => {
    const policy = { rules: [], actions: [] };
    const parsingError = { rules: true };
    expect(getSettingAlertConfig(policy, parsingError)).toEqual({ show: false, config: null });
  });

  it('still shows alert when only actions have parsing errors', () => {
    const policy = { rules: [], actions: [] };
    const parsingError = { actions: true };
    const result = getSettingAlertConfig(policy, parsingError);
    expect(result.show).toBe(true);
  });

  it('returns show: false when policy has rules and require_approval action', () => {
    const policy = {
      rules: [{ type: 'scan_finding' }],
      actions: [{ type: 'require_approval' }],
    };
    expect(getSettingAlertConfig(policy, {})).toEqual({ show: false, config: null });
  });

  it('returns danger when no rules, no actions, no project settings', () => {
    const policy = { rules: [], actions: [] };
    const result = getSettingAlertConfig(policy, {});
    expect(result.show).toBe(true);
    expect(result.config.variant).toBe('danger');
  });

  it('returns warning when no rules, no actions, but has project settings', () => {
    const policy = {
      rules: [],
      actions: [],
      approval_settings: { prevent_approval_by_author: true },
    };
    const result = getSettingAlertConfig(policy, {});
    expect(result.show).toBe(true);
    expect(result.config.variant).toBe('warning');
  });

  it('returns danger when has rules, no require_approval action, no settings', () => {
    const policy = {
      rules: [{ type: 'scan_finding' }],
      actions: [{ type: 'send_bot_message' }],
    };
    const result = getSettingAlertConfig(policy, {});
    expect(result.show).toBe(true);
    expect(result.config.variant).toBe('danger');
  });

  it('returns warning when has rules, no require_approval action, but has settings', () => {
    const policy = {
      rules: [{ type: 'scan_finding' }],
      actions: [{ type: 'send_bot_message' }],
      approval_settings: { prevent_approval_by_author: true },
    };
    const result = getSettingAlertConfig(policy, {});
    expect(result.show).toBe(true);
    expect(result.config.variant).toBe('warning');
  });

  it('returns enforced description when has rules, settings, no require_approval action, and not in warn mode', () => {
    const policy = {
      rules: [{ type: 'scan_finding' }],
      actions: [{ type: 'send_bot_message' }],
      approval_settings: { prevent_approval_by_author: true },
      enforcement_type: 'enforce',
    };
    const result = getSettingAlertConfig(policy, {});
    expect(result.show).toBe(true);
    expect(result.config.variant).toBe('warning');
    expect(result.config.description).toContain('no approvals are required');
  });

  it('returns warn mode description when has rules, settings, no require_approval action, and in warn mode', () => {
    const policy = {
      rules: [{ type: 'scan_finding' }],
      actions: [{ type: 'send_bot_message' }],
      approval_settings: { prevent_approval_by_author: true },
      enforcement_type: 'warn',
    };
    const result = getSettingAlertConfig(policy, {});
    expect(result.show).toBe(true);
    expect(result.config.variant).toBe('warning');
    expect(result.config.description).toContain('warn mode');
  });

  it('returns show: false when called without parsingError parameter', () => {
    const policy = {
      rules: [{ type: 'scan_finding' }],
      actions: [{ type: 'require_approval' }],
    };
    expect(getSettingAlertConfig(policy)).toEqual({ show: false, config: null });
  });

  it('returns danger when no rules but has require_approval action and no project settings', () => {
    const policy = {
      rules: [],
      actions: [{ type: 'require_approval' }],
    };
    const result = getSettingAlertConfig(policy, {});
    expect(result.show).toBe(true);
    expect(result.config.variant).toBe('danger');
    expect(result.config.title).toContain('no effect');
  });

  it('returns warning when no rules but has require_approval action and has project settings', () => {
    const policy = {
      rules: [],
      actions: [{ type: 'require_approval' }],
      approval_settings: { prevent_approval_by_author: true },
    };
    const result = getSettingAlertConfig(policy, {});
    expect(result.show).toBe(true);
    expect(result.config.variant).toBe('warning');
    expect(result.config.title).toContain('project approval settings');
  });
});
