import { shallowMount } from '@vue/test-utils';
import { GlCollapsibleListbox } from '@gitlab/ui';
import CodeBlockStrategySelector from 'ee/security_orchestration/components/policy_editor/pipeline_execution/action/code_block_strategy_selector.vue';
import CodeBlockDeprecatedStrategyBadge from 'ee/security_orchestration/components/policy_editor/pipeline_execution/action/code_block_deprecated_strategy_badge.vue';
import {
  INJECT,
  DEPRECATED_INJECT,
  OVERRIDE,
  CUSTOM_STRATEGY_OPTIONS,
  SCHEDULE,
} from 'ee/security_orchestration/components/policy_editor/pipeline_execution/constants';

describe('CodeBlockStrategySelector', () => {
  let wrapper;

  const defaultProvide = {
    glFeatures: { scheduledPipelineExecutionPolicies: true },
  };

  const createComponent = ({ propsData = {}, provide = {} } = {}) => {
    wrapper = shallowMount(CodeBlockStrategySelector, {
      propsData,
      stubs: {
        GlCollapsibleListbox,
      },
      provide: {
        ...defaultProvide,
        ...provide,
      },
    });
  };

  const findListBox = () => wrapper.findComponent(GlCollapsibleListbox);
  const findDeprecatedBadge = () => wrapper.findComponent(CodeBlockDeprecatedStrategyBadge);

  it('selects action type', () => {
    createComponent();
    expect(findListBox().props('selected')).toBe(INJECT);

    findListBox().vm.$emit('select', DEPRECATED_INJECT);
    expect(wrapper.emitted('select')).toEqual([[DEPRECATED_INJECT]]);

    findListBox().vm.$emit('select', OVERRIDE);
    expect(wrapper.emitted('select')[1]).toEqual([OVERRIDE]);
  });

  it.each([INJECT, OVERRIDE])('renders strategy', (strategy) => {
    createComponent({
      propsData: {
        strategy,
      },
    });

    expect(findListBox().props('selected')).toBe(strategy);
    expect(findListBox().props('toggleText')).toBe(CUSTOM_STRATEGY_OPTIONS[strategy]);
  });

  describe("'schedule' strategy visibility", () => {
    it('renders schedule strategy when feature flag is enabled', () => {
      createComponent();
      expect(findListBox().props('items')).toEqual([
        { text: 'Inject', value: INJECT },
        { text: 'Override', value: OVERRIDE },
        { text: 'Schedule a new', value: SCHEDULE },
      ]);
    });

    it('does not render schedule strategy when feature flag is disabled', () => {
      createComponent({ provide: { glFeatures: { scheduledPipelineExecutionPolicies: false } } });
      expect(findListBox().props('items')).toEqual([
        { text: 'Inject', value: INJECT },
        { text: 'Override', value: OVERRIDE },
      ]);
    });
  });

  describe('deprecated strategy', () => {
    it('renders deprecated "inject_ci" strategy in the listbox items when it is active', () => {
      createComponent({
        propsData: {
          strategy: DEPRECATED_INJECT,
        },
      });

      expect(findListBox().props('items')).toEqual([
        { text: 'Inject', value: INJECT },
        { text: 'Override', value: OVERRIDE },
        { text: 'Inject without custom stages', value: DEPRECATED_INJECT },
        { text: 'Schedule a new', value: SCHEDULE },
      ]);
    });

    it('does not render deprecated "inject_ci" strategy in the listbox items when it is not active', () => {
      createComponent({
        propsData: {
          strategy: INJECT,
        },
      });

      expect(findListBox().props('items')).toEqual([
        { text: 'Inject', value: INJECT },
        { text: 'Override', value: OVERRIDE },
        { text: 'Schedule a new', value: SCHEDULE },
      ]);
    });

    it.each`
      strategy             | expectedExists
      ${INJECT}            | ${false}
      ${DEPRECATED_INJECT} | ${true}
      ${OVERRIDE}          | ${false}
    `('renders deprecated badge for $strategy', ({ strategy, expectedExists }) => {
      createComponent({
        propsData: {
          strategy,
        },
      });

      expect(findDeprecatedBadge().exists()).toBe(expectedExists);
    });
  });
});
