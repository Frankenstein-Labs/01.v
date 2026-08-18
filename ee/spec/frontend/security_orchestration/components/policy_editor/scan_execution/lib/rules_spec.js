import {
  buildDefaultPipeLineRule,
  buildDefaultScheduleRule,
  getPredefinedRuleStrategy,
  handleBranchTypeSelect,
  hasPredefinedRuleStrategy,
  STRATEGIES_RULE_MAP,
} from 'ee/security_orchestration/components/policy_editor/scan_execution/lib/rules';
import {
  ALL_PROTECTED_BRANCHES,
  PROJECT_DEFAULT_BRANCH,
  SPECIFIC_BRANCHES,
  TARGET_BRANCHES,
} from 'ee/security_orchestration/components/policy_editor/constants';
import {
  DEFAULT_CONDITION_STRATEGY,
  SCAN_EXECUTION_RULES_PIPELINE_KEY,
} from 'ee/security_orchestration/components/policy_editor/scan_execution/constants';

const ruleId = 'rule_0';
jest.mock('lodash-es', () => ({
  ...jest.requireActual('lodash-es'),
  uniqueId: jest.fn().mockReturnValue(ruleId),
}));

describe('buildDefaultPipeLineRule', () => {
  it('builds a pipeline rule', () => {
    expect(buildDefaultPipeLineRule()).toEqual({
      branches: ['*'],
      id: ruleId,
      type: 'pipeline',
    });
  });
});

describe('buildDefaultScheduleRule', () => {
  it('builds a schedule rule with default time_window', () => {
    expect(buildDefaultScheduleRule()).toEqual({
      branches: [],
      cadence: '0 0 * * *',
      id: ruleId,
      type: 'schedule',
      time_window: {
        distribution: 'random',
        value: 36000,
      },
    });
  });
});

describe('getPredefinedRuleStrategy', () => {
  it('returns the strategy when the rules match one of the strategies', () => {
    expect(getPredefinedRuleStrategy(STRATEGIES_RULE_MAP[DEFAULT_CONDITION_STRATEGY])).toBe(
      DEFAULT_CONDITION_STRATEGY,
    );
  });

  it('returns the strategy when the rules match one of the strategies ignoring ids', () => {
    const OPTIMIZED_RULES_WITH_IDS = STRATEGIES_RULE_MAP[DEFAULT_CONDITION_STRATEGY].map(
      (rule, index) => ({
        ...rule,
        id: index.toString(),
      }),
    );
    expect(getPredefinedRuleStrategy(OPTIMIZED_RULES_WITH_IDS)).toBe(DEFAULT_CONDITION_STRATEGY);
  });

  it('returns undefined when the rules include extra rules', () => {
    expect(
      getPredefinedRuleStrategy([
        ...STRATEGIES_RULE_MAP[DEFAULT_CONDITION_STRATEGY],
        { type: 'pipeline', branch_type: 'protected' },
      ]),
    ).toBe(undefined);
  });

  it('returns undefined when the rules do not match one of the strategies', () => {
    expect(getPredefinedRuleStrategy([{ type: 'pipeline', branch_type: 'protected' }])).toBe(
      undefined,
    );
  });

  it('returns undefined when the rules do not match one of the strategies ignoring rule id', () => {
    expect(
      getPredefinedRuleStrategy([{ type: 'pipeline', branch_type: 'protected', id: '1' }]),
    ).toBe(undefined);
  });

  it('returns undefined for empty rules', () => {
    expect(getPredefinedRuleStrategy([])).toBe(undefined);
  });
});

describe('handleBranchTypeSelect', () => {
  describe('when selecting SPECIFIC_BRANCHES', () => {
    it('returns rule with branches array and removes branch_type for pipeline rules', () => {
      const rule = {
        type: SCAN_EXECUTION_RULES_PIPELINE_KEY,
        branch_type: ALL_PROTECTED_BRANCHES.value,
      };

      const result = handleBranchTypeSelect({
        branchType: SPECIFIC_BRANCHES.value,
        rule,
        pipelineRuleKey: SCAN_EXECUTION_RULES_PIPELINE_KEY,
      });

      expect(result).toEqual({
        type: SCAN_EXECUTION_RULES_PIPELINE_KEY,
        branches: ['*'],
      });
      expect(result.branch_type).toBeUndefined();
    });

    it('returns rule with empty branches array for non-pipeline rules', () => {
      const rule = {
        type: 'schedule',
        branch_type: ALL_PROTECTED_BRANCHES.value,
      };

      const result = handleBranchTypeSelect({
        branchType: SPECIFIC_BRANCHES.value,
        rule,
        pipelineRuleKey: SCAN_EXECUTION_RULES_PIPELINE_KEY,
      });

      expect(result).toEqual({
        type: 'schedule',
        branches: [],
      });
      expect(result.branch_type).toBeUndefined();
    });

    it('preserves other properties in the rule', () => {
      const rule = {
        type: SCAN_EXECUTION_RULES_PIPELINE_KEY,
        branch_type: ALL_PROTECTED_BRANCHES.value,
        actions: ['scan'],
        branch_exceptions: ['main'],
      };

      const result = handleBranchTypeSelect({
        branchType: SPECIFIC_BRANCHES.value,
        rule,
        pipelineRuleKey: SCAN_EXECUTION_RULES_PIPELINE_KEY,
      });

      expect(result).toEqual({
        type: SCAN_EXECUTION_RULES_PIPELINE_KEY,
        branches: ['*'],
        actions: ['scan'],
        branch_exceptions: ['main'],
      });
    });
  });

  describe('when selecting a branch type other than SPECIFIC_BRANCHES', () => {
    it('returns rule with branch_type and removes branches property', () => {
      const rule = {
        type: SCAN_EXECUTION_RULES_PIPELINE_KEY,
        branches: ['feature/*'],
      };

      const result = handleBranchTypeSelect({
        branchType: ALL_PROTECTED_BRANCHES.value,
        rule,
        pipelineRuleKey: SCAN_EXECUTION_RULES_PIPELINE_KEY,
      });

      expect(result).toEqual({
        type: SCAN_EXECUTION_RULES_PIPELINE_KEY,
        branch_type: ALL_PROTECTED_BRANCHES.value,
      });
      expect(result.branches).toBeUndefined();
    });

    it('preserves other properties in the rule', () => {
      const rule = {
        type: 'schedule',
        branches: ['feature/*'],
        actions: ['scan'],
        branch_exceptions: ['main'],
      };

      const result = handleBranchTypeSelect({
        branchType: PROJECT_DEFAULT_BRANCH.value,
        rule,
        pipelineRuleKey: SCAN_EXECUTION_RULES_PIPELINE_KEY,
      });

      expect(result).toEqual({
        type: 'schedule',
        branch_type: PROJECT_DEFAULT_BRANCH.value,
        actions: ['scan'],
        branch_exceptions: ['main'],
      });
    });
  });

  describe('pipeline_sources handling', () => {
    it('does not modify the pipeline_sources property when switching between non-target branches', () => {
      const rule = {
        branches: ['feature/*'],
        pipeline_sources: { including: ['web', 'api'] },
        type: SCAN_EXECUTION_RULES_PIPELINE_KEY,
      };

      const result = handleBranchTypeSelect({
        branchType: 'non-target-branch-type', // Not in TARGET_BRANCHES
        rule,
        pipelineRuleKey: SCAN_EXECUTION_RULES_PIPELINE_KEY,
      });

      expect(result.pipeline_sources.including).toEqual(['web', 'api']);
    });

    it('modifies the pipeline_sources property when switching between non-target branch type and target branch type', () => {
      const rule = {
        branch_type: 'protected',
        pipeline_sources: { including: ['push'] },
        type: SCAN_EXECUTION_RULES_PIPELINE_KEY,
      };

      const result = handleBranchTypeSelect({
        branchType: TARGET_BRANCHES[0],
        rule,
        pipelineRuleKey: SCAN_EXECUTION_RULES_PIPELINE_KEY,
      });

      expect(result.pipeline_sources.including).toEqual(['merge_request_event', 'push']);
    });

    it('modifies the pipeline_sources property when switching between target branch type and non-target branch type', () => {
      const rule = {
        branch_type: TARGET_BRANCHES[0],
        pipeline_sources: { including: ['push'] },
        type: SCAN_EXECUTION_RULES_PIPELINE_KEY,
      };

      const result = handleBranchTypeSelect({
        branchType: 'default',
        rule,
        pipelineRuleKey: SCAN_EXECUTION_RULES_PIPELINE_KEY,
      });

      expect(result.pipeline_sources).toBeUndefined();
    });

    it('does not modify the pipeline_sources property when switching between target branch type', () => {
      const rule = {
        branch_type: TARGET_BRANCHES[0],
        pipeline_sources: { including: ['push'] },
        type: SCAN_EXECUTION_RULES_PIPELINE_KEY,
      };

      const result = handleBranchTypeSelect({
        branchType: TARGET_BRANCHES[1],
        rule,
        pipelineRuleKey: SCAN_EXECUTION_RULES_PIPELINE_KEY,
      });

      expect(result.pipeline_sources.including).toEqual(['push']);
    });
  });
});

describe('hasPredefinedRuleStrategy', () => {
  it('returns true when the rules match one of the strategies', () => {
    expect(hasPredefinedRuleStrategy(STRATEGIES_RULE_MAP[DEFAULT_CONDITION_STRATEGY])).toBe(true);
  });

  it('returns true when the rules match one of the strategies ignoring ids', () => {
    const OPTIMIZED_RULES_WITH_IDS = STRATEGIES_RULE_MAP[DEFAULT_CONDITION_STRATEGY].map(
      (rule, index) => ({
        ...rule,
        id: index.toString(),
      }),
    );
    expect(hasPredefinedRuleStrategy(OPTIMIZED_RULES_WITH_IDS)).toBe(true);
  });

  it('returns false when the rules include extra rules', () => {
    expect(
      hasPredefinedRuleStrategy([
        ...STRATEGIES_RULE_MAP[DEFAULT_CONDITION_STRATEGY],
        { type: 'pipeline', branch_type: 'protected' },
      ]),
    ).toBe(false);
  });

  it('returns false when the rules do not match one of the strategies', () => {
    expect(hasPredefinedRuleStrategy([{ type: 'pipeline', branch_type: 'protected' }])).toBe(false);
  });

  it('returns false when the rules do not match one of the strategies ignoring rule id', () => {
    expect(
      hasPredefinedRuleStrategy([{ type: 'pipeline', branch_type: 'protected', id: '1' }]),
    ).toBe(false);
  });

  it('returns false for empty rules', () => {
    expect(hasPredefinedRuleStrategy([])).toBe(false);
  });
});
