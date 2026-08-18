import {
  DEFAULT_PIPELINE_EXECUTION_POLICY,
  DEFAULT_PIPELINE_EXECUTION_POLICY_WITH_SUFFIX,
  DEFAULT_SCHEDULE,
  INJECT,
  INJECT_CI_PIPELINE_EXECUTION_POLICY,
  OVERRIDE,
  PIPELINE_EXECUTION_SCHEDULE_POLICY,
  SCHEDULE,
} from 'ee/security_orchestration/components/policy_editor/pipeline_execution/constants';
import {
  createPolicyObject,
  getInitialPolicy,
  getPipelineConfigStrategyType,
  updatePolicyStrategy,
  validatePolicy,
} from 'ee/security_orchestration/components/policy_editor/pipeline_execution/utils';
import { fromYaml } from 'ee/security_orchestration/components/utils';
import {
  customYaml,
  customYamlObject,
  customYamlObjectFromUrlParams,
  customYamlUrlParams,
  mockInvalidStrategyPipelineExecutionManifest,
  mockInvalidStrategyPipelineExecutionObject,
  mockInvalidTypePipelineExecutionManifest,
  invalidYaml,
  mockPipelineExecutionObject,
  mockWithInjectCiPipelineExecutionObject,
  mockWithSuffixPipelineExecutionObject,
  mockSchedulePipelineExecutionObject,
  mockSchedulePipelineExecutionManifest,
  mockInvalidStrategyPipelineExecutionPolicy,
  mockInvalidContentPipelineExecutionPolicy,
  mockNoStrategyPipelineExecutionPolicy,
  mockObjectStrategyPipelineExecutionPolicy,
} from 'ee_jest/security_orchestration/mocks/mock_pipeline_execution_policy_data';
import {
  policyBodyToYaml,
  policyToYaml,
} from 'ee/security_orchestration/components/policy_editor/utils';
import { PIPELINE_EXECUTION_POLICY_TYPE } from 'ee/security_orchestration/components/constants';

describe('fromYaml', () => {
  it.each`
    title                                                                     | input                                                                                                | output
    ${'returns the policy object for a supported manifest'}                   | ${{ manifest: DEFAULT_PIPELINE_EXECUTION_POLICY, type: PIPELINE_EXECUTION_POLICY_TYPE }}             | ${mockPipelineExecutionObject}
    ${'returns the policy object for a supported manifest with inject_ci'}    | ${{ manifest: INJECT_CI_PIPELINE_EXECUTION_POLICY, type: PIPELINE_EXECUTION_POLICY_TYPE }}           | ${mockWithInjectCiPipelineExecutionObject}
    ${'returns the policy object for a supported manifest with schedules'}    | ${{ manifest: mockSchedulePipelineExecutionManifest, type: PIPELINE_EXECUTION_SCHEDULE_POLICY }}     | ${mockSchedulePipelineExecutionObject}
    ${'returns the policy object for a supported manifest with suffix'}       | ${{ manifest: DEFAULT_PIPELINE_EXECUTION_POLICY_WITH_SUFFIX, type: PIPELINE_EXECUTION_POLICY_TYPE }} | ${mockWithSuffixPipelineExecutionObject}
    ${'returns the policy object for a policy with an unsupported attribute'} | ${{ manifest: customYaml, type: PIPELINE_EXECUTION_POLICY_TYPE }}                                    | ${{ type: 'pipeline_execution_policy', ...customYamlObject }}
    ${'returns empty object for a policy with an invalid yaml'}               | ${{ manifest: invalidYaml, type: PIPELINE_EXECUTION_POLICY_TYPE }}                                   | ${{}}
  `('$title', ({ input, output }) => {
    expect(fromYaml(input)).toStrictEqual(output);
  });
});

describe('updatePolicyStrategy', () => {
  const basePolicy = {
    name: 'Test Policy',
    description: 'Test Description',
    enabled: true,
    content: { include: [{ project: 'test-project' }] },
  };

  describe('when switching to SCHEDULE strategy', () => {
    it('removes pipeline_config_strategy and adds schedules', () => {
      const oldPolicy = {
        ...basePolicy,
        pipeline_config_strategy: INJECT,
      };

      const policy = updatePolicyStrategy({ policy: oldPolicy, strategy: SCHEDULE });

      expect(policy).not.toHaveProperty('pipeline_config_strategy');
      expect(policy.schedules).toEqual([DEFAULT_SCHEDULE]);
      expect(policy.type).toBe(PIPELINE_EXECUTION_SCHEDULE_POLICY);
    });

    it('preserves other policy properties', () => {
      const oldPolicy = {
        ...basePolicy,
        pipeline_config_strategy: INJECT,
      };

      const policy = updatePolicyStrategy({ policy: oldPolicy, strategy: SCHEDULE });

      expect(policy.name).toBe(basePolicy.name);
      expect(policy.description).toBe(basePolicy.description);
      expect(policy.enabled).toBe(basePolicy.enabled);
      expect(policy.content).toEqual(basePolicy.content);
    });
  });

  describe('when switching from SCHEDULE to another strategy', () => {
    it('adds pipeline_config_strategy and removes schedules', () => {
      const oldPolicy = {
        ...basePolicy,
        schedules: [DEFAULT_SCHEDULE],
      };

      const policy = updatePolicyStrategy({ policy: oldPolicy, strategy: INJECT });

      expect(policy.pipeline_config_strategy).toBe(INJECT);
      expect(policy).not.toHaveProperty('schedules');
      expect(policy.type).toBe(PIPELINE_EXECUTION_POLICY_TYPE);
    });

    it('preserves other policy properties', () => {
      const oldPolicy = {
        ...basePolicy,
        schedules: [DEFAULT_SCHEDULE],
      };

      const policy = updatePolicyStrategy({ policy: oldPolicy, strategy: INJECT });

      expect(policy.name).toBe(basePolicy.name);
      expect(policy.description).toBe(basePolicy.description);
      expect(policy.enabled).toBe(basePolicy.enabled);
      expect(policy.content).toEqual(basePolicy.content);
    });
  });

  describe('when the current strategy is an object', () => {
    it('updates the type while preserving apply_on_empty_pipeline', () => {
      const oldPolicy = {
        ...basePolicy,
        pipeline_config_strategy: { type: INJECT, apply_on_empty_pipeline: 'never' },
      };

      const policy = updatePolicyStrategy({ policy: oldPolicy, strategy: OVERRIDE });

      expect(policy.pipeline_config_strategy).toEqual({
        type: OVERRIDE,
        apply_on_empty_pipeline: 'never',
      });
    });
  });
});

describe('getPipelineConfigStrategyType', () => {
  it.each([
    [undefined, undefined],
    [null, null],
    ['inject_policy', 'inject_policy'],
    [{ type: 'inject_policy', apply_on_empty_pipeline: 'never' }, 'inject_policy'],
    [{ apply_on_empty_pipeline: 'never' }, undefined],
  ])('returns the strategy type for %p', (input, output) => {
    expect(getPipelineConfigStrategyType(input)).toBe(output);
  });
});

describe('validatePolicy', () => {
  it.each`
    title                                                               | input                                                                                                       | output
    ${'returns empty object when there are no errors'}                  | ${fromYaml({ manifest: DEFAULT_PIPELINE_EXECUTION_POLICY, type: PIPELINE_EXECUTION_POLICY_TYPE })}          | ${{}}
    ${'returns empty object when there are no errors for schedule PEP'} | ${fromYaml({ manifest: mockSchedulePipelineExecutionManifest, type: PIPELINE_EXECUTION_SCHEDULE_POLICY })}  | ${{}}
    ${'returns empty object when the strategy is defined as an object'} | ${fromYaml({ manifest: mockObjectStrategyPipelineExecutionPolicy, type: PIPELINE_EXECUTION_POLICY_TYPE })}  | ${{}}
    ${'returns error objects when there are invalid pipeline strategy'} | ${fromYaml({ manifest: mockInvalidStrategyPipelineExecutionPolicy, type: PIPELINE_EXECUTION_POLICY_TYPE })} | ${{ actions: true }}
    ${'returns error objects when there is invalid content'}            | ${fromYaml({ manifest: mockInvalidContentPipelineExecutionPolicy, type: PIPELINE_EXECUTION_POLICY_TYPE })}  | ${{ actions: true }}
    ${'returns error objects when there is no pipeline strategy'}       | ${fromYaml({ manifest: mockNoStrategyPipelineExecutionPolicy, type: PIPELINE_EXECUTION_POLICY_TYPE })}      | ${{ actions: true }}
  `('$title', ({ input, output }) => {
    expect(validatePolicy(input)).toStrictEqual(output);
  });
});

describe('createPolicyObject', () => {
  it.each`
    title                                                                                   | input                                           | output
    ${'returns the policy object and no errors for a supported manifest'}                   | ${DEFAULT_PIPELINE_EXECUTION_POLICY}            | ${{ policy: fromYaml({ manifest: DEFAULT_PIPELINE_EXECUTION_POLICY, type: PIPELINE_EXECUTION_POLICY_TYPE }), parsingError: {} }}
    ${'returns the policy object and no errors for a supported manifest with inject_ci'}    | ${INJECT_CI_PIPELINE_EXECUTION_POLICY}          | ${{ policy: fromYaml({ manifest: INJECT_CI_PIPELINE_EXECUTION_POLICY, type: PIPELINE_EXECUTION_POLICY_TYPE }), parsingError: {} }}
    ${'returns the policy object and no errors for a supported manifest with schedule PEP'} | ${mockSchedulePipelineExecutionManifest}        | ${{ policy: fromYaml({ manifest: mockSchedulePipelineExecutionManifest, type: PIPELINE_EXECUTION_SCHEDULE_POLICY }), parsingError: {} }}
    ${'returns the error policy object and the error for an invalid strategy name'}         | ${mockInvalidStrategyPipelineExecutionManifest} | ${{ policy: mockInvalidStrategyPipelineExecutionObject, parsingError: { actions: true } }}
    ${'returns the policy object and no errors for a manifest with an invalid type'}        | ${mockInvalidTypePipelineExecutionManifest}     | ${{ policy: fromYaml({ manifest: DEFAULT_PIPELINE_EXECUTION_POLICY, type: PIPELINE_EXECUTION_POLICY_TYPE }), parsingError: {} }}
    ${'returns the policy object and no errors for an object strategy manifest'}            | ${mockObjectStrategyPipelineExecutionPolicy}    | ${{ policy: fromYaml({ manifest: mockObjectStrategyPipelineExecutionPolicy, type: PIPELINE_EXECUTION_POLICY_TYPE }), parsingError: {} }}
  `('$title', ({ input, output }) => {
    expect(createPolicyObject(input)).toStrictEqual(output);
  });

  it('preserves the object strategy and its apply_on_empty_pipeline option', () => {
    const { policy } = createPolicyObject(mockObjectStrategyPipelineExecutionPolicy);

    expect(policy.pipeline_config_strategy).toEqual({
      type: 'inject_policy',
      apply_on_empty_pipeline: 'never',
    });
  });
});

describe('policyToYaml', () => {
  it('returns policy object as yaml', () => {
    expect(policyToYaml(customYamlObject, PIPELINE_EXECUTION_POLICY_TYPE)).toBe(
      `pipeline_execution_policy:
  - ${customYaml}`,
    );
  });
});

describe('toYaml', () => {
  it('returns policy object as yaml', () => {
    expect(policyBodyToYaml(customYamlObject)).toBe(customYaml);
  });
});

describe('getInitialPolicy', () => {
  it('updates initialPolicy with passed params if all params are present', () => {
    const expectedYaml = customYamlObjectFromUrlParams(customYamlUrlParams);
    expect(getInitialPolicy(customYaml, customYamlUrlParams)).toBe(expectedYaml);
  });

  it.each(Object.keys(customYamlUrlParams).map((key) => [key]))(
    'ignores other url params if %s is missing',
    (key) => {
      const params = { ...customYamlUrlParams };
      delete params[key];
      expect(getInitialPolicy(customYaml, params)).toBe(customYaml);
    },
  );
});
