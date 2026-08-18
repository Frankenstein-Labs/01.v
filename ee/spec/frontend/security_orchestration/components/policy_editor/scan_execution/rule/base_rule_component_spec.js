import { nextTick } from 'vue';
import { GlCollapsibleListbox, GlSprintf } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import BaseRuleComponent from 'ee/security_orchestration/components/policy_editor/scan_execution/rule/base_rule_component.vue';
import BranchTypeSelector from 'ee/security_orchestration/components/policy_editor/scan_execution/rule/branch_type_selector.vue';
import BranchExceptionSelector from 'ee/security_orchestration/components/policy_editor/branch_exception_selector.vue';
import PipelineSourceSelector from 'ee/security_orchestration/components/policy_editor/scan_execution/rule/pipeline_source_selector.vue';
import {
  SCAN_EXECUTION_SCHEDULE_RULE,
  SCAN_EXECUTION_PIPELINE_RULE,
  SCAN_EXECUTION_RULES_PIPELINE_KEY,
} from 'ee/security_orchestration/components/policy_editor/scan_execution/constants';
import {
  ALL_PROTECTED_BRANCHES,
  SPECIFIC_BRANCHES,
  TARGET_BRANCHES,
  TARGET_DEFAULT,
  VALID_SCAN_EXECUTION_BRANCH_TYPE_OPTIONS,
} from 'ee/security_orchestration/components/policy_editor/constants';
import { NAMESPACE_TYPES } from 'ee/security_orchestration/constants';

describe('BaseRuleComponent', () => {
  let wrapper;
  const initRule = {
    type: SCAN_EXECUTION_SCHEDULE_RULE,
    branches: [],
  };

  const createComponent = ({ props = {}, provide = {} } = {}) => {
    wrapper = shallowMountExtended(BaseRuleComponent, {
      propsData: {
        initRule,
        ...props,
      },
      provide: {
        namespaceType: NAMESPACE_TYPES.PROJECT,
        ...provide,
      },
      stubs: {
        GlSprintf,
      },
    });
  };

  const findBranchesLabel = () => wrapper.findByTestId('rule-branches-label');
  const findBranchTypeSelector = () => wrapper.findComponent(BranchTypeSelector);
  const findBranchExceptionSelector = () => wrapper.findComponent(BranchExceptionSelector);
  const findDeleteButton = () => wrapper.findComponentByTestId('remove-rule');
  const findPipelineSourceSelector = () => wrapper.findComponent(PipelineSourceSelector);
  const findRuleTypeDropDown = () => wrapper.findComponent(GlCollapsibleListbox);

  const selectBranches = async (branches) => {
    findBranchTypeSelector().vm.$emit('input', branches);
    await nextTick();
  };

  describe('rendering', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders pipeline rule by default', () => {
      expect(findRuleTypeDropDown().props('selected')).toBe(SCAN_EXECUTION_RULES_PIPELINE_KEY);
    });

    it('renders pipeline rule component by default', () => {
      expect(findRuleTypeDropDown().props('selected')).toBe(SCAN_EXECUTION_RULES_PIPELINE_KEY);
      expect(findBranchTypeSelector().props('branchesToAdd')).toBe('');
    });

    it('selects pipeline rule', async () => {
      findRuleTypeDropDown().vm.$emit('select', SCAN_EXECUTION_RULES_PIPELINE_KEY);
      await nextTick();
      const [eventPayload] = wrapper.emitted()['select-rule'];

      expect(eventPayload[0]).toEqual(SCAN_EXECUTION_RULES_PIPELINE_KEY);
    });

    it('selects list of branches', async () => {
      const branches = ['main,branch1,branch2'];

      await selectBranches(branches);
      const [eventPayload] = wrapper.emitted().changed;

      expect(eventPayload[0]).toEqual({
        type: SCAN_EXECUTION_SCHEDULE_RULE,
        branches,
      });
    });

    it.each`
      isBranchScope | expectedResult
      ${true}       | ${true}
      ${false}      | ${false}
    `('renders branches input', ({ isBranchScope, expectedResult }) => {
      createComponent({
        props: { isBranchScope },
      });

      expect(findBranchTypeSelector().exists()).toBe(expectedResult);
    });

    it('emits array of branches and correct type', async () => {
      await selectBranches(['main', 'branch']);

      expect(wrapper.emitted('changed')).toEqual([
        [{ branches: ['main', 'branch'], type: SCAN_EXECUTION_SCHEDULE_RULE }],
      ]);
    });

    it('trims branch names from white spaces', async () => {
      await selectBranches(['main', 'branch', 'branch2']);

      expect(wrapper.emitted()).toEqual({
        changed: [
          [{ branches: ['main', 'branch', 'branch2'], type: SCAN_EXECUTION_SCHEDULE_RULE }],
        ],
      });
    });

    it('selects correct rule', async () => {
      findRuleTypeDropDown().vm.$emit('select', SCAN_EXECUTION_RULES_PIPELINE_KEY);

      await nextTick();

      expect(wrapper.emitted()).toEqual({
        'select-rule': [[SCAN_EXECUTION_PIPELINE_RULE]],
      });
    });

    it('removes rule', async () => {
      findDeleteButton().vm.$emit('click');

      await nextTick();

      expect(wrapper.emitted()).toEqual({
        remove: [[]],
      });
    });
  });

  describe('branches label', () => {
    it('displays "branches" if a branch has the wildcard operator', async () => {
      createComponent({
        props: {
          initRule: {
            type: SCAN_EXECUTION_SCHEDULE_RULE,
            branches: ['releases/*'],
          },
        },
      });
      await nextTick();
      expect(findBranchesLabel().text()).toBe('branches');
    });

    it('displays "branch" if a branch does not have the wildcard operator', async () => {
      createComponent({
        props: {
          initRule: {
            type: SCAN_EXECUTION_SCHEDULE_RULE,
            branches: ['main'],
          },
        },
      });
      await nextTick();
      expect(findBranchesLabel().text()).toBe('branch');
    });
  });

  describe('branch types', () => {
    it.each(VALID_SCAN_EXECUTION_BRANCH_TYPE_OPTIONS)(
      'should select branch type %s',
      (branchType) => {
        createComponent();

        findBranchTypeSelector().vm.$emit('set-branch-type', branchType);

        const expected = { type: SCAN_EXECUTION_SCHEDULE_RULE, branch_type: branchType };
        if (TARGET_BRANCHES.includes(branchType)) {
          expected.pipeline_sources = { including: ['merge_request_event', 'push'] };
        }

        expect(wrapper.emitted('changed')).toEqual([[expected]]);
      },
    );

    it.each`
      type                            | emittedValue
      ${SCAN_EXECUTION_PIPELINE_RULE} | ${['*']}
      ${SCAN_EXECUTION_SCHEDULE_RULE} | ${[]}
    `('should select branches for specific branch type', ({ type, emittedValue }) => {
      createComponent({
        props: {
          initRule: {
            type,
            branch_type: ALL_PROTECTED_BRANCHES.value,
          },
        },
      });

      expect(findBranchTypeSelector().props('selectedBranchType')).toBe(
        ALL_PROTECTED_BRANCHES.value,
      );

      findBranchTypeSelector().vm.$emit('set-branch-type', SPECIFIC_BRANCHES.value);

      expect(wrapper.emitted('changed')).toEqual([
        [
          {
            type,
            branches: emittedValue,
          },
        ],
      ]);
    });
  });

  describe('branch exceptions', () => {
    const exceptions = { branch_exceptions: ['main', 'test'] };

    it.each`
      title                                                       | namespaceType              | expectedResult
      ${'renders branch exception selector on the project level'} | ${NAMESPACE_TYPES.PROJECT} | ${true}
      ${'renders branch exception selector on the group level'}   | ${NAMESPACE_TYPES.GROUP}   | ${true}
    `('$title', ({ namespaceType, expectedResult }) => {
      createComponent({
        provide: {
          namespaceType,
        },
      });

      expect(findBranchExceptionSelector().exists()).toBe(expectedResult);
    });

    it('selects exceptions', () => {
      createComponent();

      findBranchExceptionSelector().vm.$emit('select', exceptions);

      expect(wrapper.emitted('changed')).toEqual([
        [
          {
            ...initRule,
            ...exceptions,
          },
        ],
      ]);
    });

    it('displays saved exceptions', () => {
      createComponent({
        props: {
          initRule: {
            ...initRule,
            ...exceptions,
          },
        },
      });

      expect(findBranchExceptionSelector().props('selectedExceptions')).toEqual(
        exceptions.branch_exceptions,
      );
    });

    it('should remove selection from rule', () => {
      createComponent({
        props: {
          initRule: {
            ...initRule,
            ...exceptions,
          },
        },
      });

      findBranchExceptionSelector().vm.$emit('remove');

      expect(wrapper.emitted('changed')).toEqual([
        [
          {
            ...initRule,
          },
        ],
      ]);
    });
  });

  describe('pipeline source dropdown', () => {
    describe('rendering', () => {
      it('renders for branch type that does not target other branches', () => {
        createComponent({
          props: {
            initRule: {
              type: SCAN_EXECUTION_RULES_PIPELINE_KEY,
              branch_type: ALL_PROTECTED_BRANCHES.value,
            },
          },
        });

        expect(findPipelineSourceSelector().exists()).toBe(true);
        expect(findPipelineSourceSelector().props()).toEqual({
          showAllSources: true,
          pipelineSources: {},
        });
      });

      it('renders for branch type that targets other branches', () => {
        createComponent({
          props: {
            initRule: {
              type: SCAN_EXECUTION_RULES_PIPELINE_KEY,
              branch_type: TARGET_DEFAULT,
            },
          },
        });

        expect(findPipelineSourceSelector().exists()).toBe(true);
        expect(findPipelineSourceSelector().props()).toEqual({
          showAllSources: false,
          pipelineSources: {},
        });
      });
    });

    describe('selection', () => {
      it('updates the rule when pipeline sources are selected', async () => {
        createComponent({
          props: {
            initRule: {
              type: SCAN_EXECUTION_RULES_PIPELINE_KEY,
              branch_type: TARGET_DEFAULT,
            },
          },
        });
        const pipelineSources = { pipeline_sources: { including: ['web', 'api'] } };
        await findPipelineSourceSelector().vm.$emit('select', pipelineSources);

        expect(wrapper.emitted('changed')[0][0]).toEqual(expect.objectContaining(pipelineSources));
      });

      it('should remove selection from rule', () => {
        const pipelineRule = {
          type: SCAN_EXECUTION_RULES_PIPELINE_KEY,
          branch_type: TARGET_DEFAULT,
        };

        createComponent({
          props: {
            initRule: { ...pipelineRule, pipeline_sources: { including: ['api'] } },
          },
        });
        findPipelineSourceSelector().vm.$emit('remove');
        expect(wrapper.emitted('changed')).toEqual([[{ ...pipelineRule }]]);
      });
    });
  });
});
