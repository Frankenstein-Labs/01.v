import { shallowMount } from '@vue/test-utils';
import { GlBadge, GlPopover, GlSprintf } from '@gitlab/ui';
import CodeBlockDeprecatedStrategyBadge from 'ee/security_orchestration/components/policy_editor/pipeline_execution/action/code_block_deprecated_strategy_badge.vue';

describe('CodeBlockDeprecatedStrategySelector', () => {
  let wrapper;

  const createComponent = () => {
    wrapper = shallowMount(CodeBlockDeprecatedStrategyBadge, {
      stubs: { GlSprintf },
    });
  };

  const findBadge = () => wrapper.findComponent(GlBadge);
  const findPopover = () => wrapper.findComponent(GlPopover);

  it('renders badge', () => {
    createComponent();

    expect(findBadge().exists()).toBe(true);
  });

  it('renders popover', () => {
    createComponent();

    expect(findPopover().text()).toContain(
      'inject_ci strategy was deprecated. It was replaced by inject_policy which enforces custom stages. Learn more.',
    );
  });
});
