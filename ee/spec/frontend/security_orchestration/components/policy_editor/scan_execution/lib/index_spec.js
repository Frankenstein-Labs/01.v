import { REPORT_TYPE_DAST } from '~/vue_shared/security_reports/constants';
import {
  DEFAULT_SCAN_EXECUTION_POLICY,
  DEFAULT_SCAN_EXECUTION_POLICY_WITH_SCOPE,
  STRATEGIES_RULE_MAP,
  getPolicyYaml,
  getConfiguration,
} from 'ee/security_orchestration/components/policy_editor/scan_execution/lib';
import { isGroup } from 'ee/security_orchestration/components/utils';
import { NAMESPACE_TYPES } from 'ee/security_orchestration/constants';
import {
  DEFAULT_CONDITION_STRATEGY,
  SELECTION_CONFIG_CUSTOM,
  SELECTION_CONFIG_DEFAULT,
} from 'ee/security_orchestration/components/policy_editor/scan_execution/constants';

describe('getPolicyYaml', () => {
  it.each`
    namespaceType              | expected
    ${NAMESPACE_TYPES.PROJECT} | ${DEFAULT_SCAN_EXECUTION_POLICY}
    ${NAMESPACE_TYPES.GROUP}   | ${DEFAULT_SCAN_EXECUTION_POLICY_WITH_SCOPE}
  `('returns the optimized yaml for $namespaceType namespace', ({ namespaceType, expected }) => {
    expect(getPolicyYaml({ isGroup: isGroup(namespaceType) })).toEqual(expected);
  });
});

describe('getConfiguration', () => {
  it('returns "default" when all conditions are met', () => {
    const policy = {
      actions: [{ scan: 'sast', template: 'latest' }],
      rules: STRATEGIES_RULE_MAP[DEFAULT_CONDITION_STRATEGY],
    };
    expect(getConfiguration(policy)).toBe(SELECTION_CONFIG_DEFAULT);
  });

  it('returns "custom" when hasOptimizedRules is false', () => {
    const policy = { actions: [{ scan: 'sast', template: 'latest' }], rules: [{}] };

    expect(getConfiguration(policy)).toBe(SELECTION_CONFIG_CUSTOM);
  });

  it('returns "custom" when hasOnlyAllowedScans is false', () => {
    const policy = {
      actions: [{ scan: REPORT_TYPE_DAST, template: 'latest' }],
      rules: STRATEGIES_RULE_MAP[DEFAULT_CONDITION_STRATEGY],
    };

    expect(getConfiguration(policy)).toBe(SELECTION_CONFIG_CUSTOM);
  });

  it('returns "custom" when hasUniqueScans is false', () => {
    const policy = {
      actions: [
        { scan: 'sast', template: 'latest' },
        { scan: 'sast', template: 'latest' },
      ],
      rules: STRATEGIES_RULE_MAP[DEFAULT_CONDITION_STRATEGY],
    };

    expect(getConfiguration(policy)).toBe(SELECTION_CONFIG_CUSTOM);
  });

  it('returns "custom" when hasSimpleScans is false', () => {
    const policy = {
      actions: [{ scan: REPORT_TYPE_DAST, template: 'latest' }],
      rules: STRATEGIES_RULE_MAP[DEFAULT_CONDITION_STRATEGY],
    };

    expect(getConfiguration(policy)).toBe(SELECTION_CONFIG_CUSTOM);
  });

  it('handles policy with no actions and no rules', () => {
    const policy = { actions: [], rules: [] };

    expect(getConfiguration(policy)).toBe(SELECTION_CONFIG_CUSTOM);
  });
});
