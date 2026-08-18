import { GlLink } from '@gitlab/ui';
import { shallowMount } from '@vue/test-utils';
import EmptyRuleApprovers from 'ee/approvals/components/rules/empty_rule_approvers.vue';

describe('Empty Rule Name', () => {
  let wrapper;

  const createComponent = (props = {}) => {
    wrapper = shallowMount(EmptyRuleApprovers, {
      propsData: {
        rule: {},
        eligibleApproversDocsPath: 'some/path',
        ...props,
      },
    });
  };

  it('has a rule name "Any eligible user"', () => {
    createComponent();

    expect(wrapper.text()).toContain('Any eligible user');
  });

  it('renders a "more information" link', () => {
    createComponent();

    expect(wrapper.findComponent(GlLink).attributes('href')).toBe(
      wrapper.props('eligibleApproversDocsPath'),
    );
    expect(wrapper.findComponent(GlLink).exists()).toBe(true);
    expect(wrapper.findComponent(GlLink).text()).toBe('More information');
  });
});
