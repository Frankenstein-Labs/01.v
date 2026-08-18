import { GlButton } from '@gitlab/ui';
import { shallowMount } from '@vue/test-utils';
import EmptyRule from 'ee/approvals/components/rules/empty_rule.vue';
import RuleBranches from 'ee/approvals/components/rules/rule_branches.vue';

describe('Empty Rule', () => {
  let wrapper;

  const createComponent = (props = {}) => {
    wrapper = shallowMount(EmptyRule, {
      propsData: {
        rule: {},
        ...props,
      },
    });
  };

  describe('isBranchRulesEdit', () => {
    const findBranches = () => wrapper.findComponent(RuleBranches);
    const defaultProps = { allowMultiRule: true, isMrEdit: false, canEdit: true };

    it('does not render branches when `true`', () => {
      createComponent({ ...defaultProps, isBranchRulesEdit: true });

      expect(findBranches().exists()).toBe(false);
    });

    it('renders branches when `false`', () => {
      createComponent({ ...defaultProps, isBranchRulesEdit: false });

      expect(findBranches().exists()).toBe(true);
    });
  });

  describe('multiple rules', () => {
    it('does not display "Add approval rule" button', () => {
      createComponent({
        allowMultiRule: true,
        canEdit: true,
      });
      expect(wrapper.findComponent(GlButton).exists()).toBe(false);
    });
  });

  describe('single rule', () => {
    it('displays "Add approval rule" button if allowed to edit', () => {
      createComponent({
        allowMultiRule: false,
        canEdit: true,
      });

      expect(wrapper.findComponent(GlButton).exists()).toBe(true);
    });

    it('does not display "Add approval rule" button if not allowed to edit', () => {
      createComponent({
        allowMultiRule: true,
        canEdit: false,
      });
      expect(wrapper.findComponent(GlButton).exists()).toBe(false);
    });
  });
});
