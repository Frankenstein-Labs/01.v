import { GlSprintf, GlButton } from '@gitlab/ui';
import { shallowMount } from '@vue/test-utils';
import UnconfiguredSecurityRule from 'ee/approvals/components/security_configuration/unconfigured_security_rule.vue';
import { COVERAGE_CHECK_NAME } from 'ee/approvals/constants';

describe('UnconfiguredSecurityRule component', () => {
  let wrapper;

  const findDescription = () => wrapper.findComponent(GlSprintf);
  const findButton = () => wrapper.findComponent(GlButton);

  const coverageCheckRule = {
    name: COVERAGE_CHECK_NAME,
    description: 'coverage-check description with enable button',
    docsPath: 'docs/coverage-check',
  };

  const createWrapper = (props = {}) => {
    wrapper = shallowMount(UnconfiguredSecurityRule, {
      propsData: {
        ...props,
      },
      stubs: {
        GlSprintf,
      },
    });
  };

  describe.each`
    rule                 | ruleName                  | descriptionText
    ${coverageCheckRule} | ${coverageCheckRule.name} | ${coverageCheckRule.description}
  `('with $ruleName', ({ rule, descriptionText }) => {
    beforeEach(() => {
      createWrapper({ rule: { ...rule } });
    });

    it('renders the row with the enable description and enable button', () => {
      expect(findDescription().exists()).toBe(true);
      expect(wrapper.text()).toContain(descriptionText);
      expect(findButton().exists()).toBe(true);
    });

    it('emits the "enable" event when the button is clicked', () => {
      findButton().vm.$emit('click');
      expect(wrapper.emitted('enable')).toEqual([[]]);
    });
  });
});
