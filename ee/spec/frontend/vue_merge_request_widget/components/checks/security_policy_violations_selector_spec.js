import { GlButton } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import SecurityPolicyViolationsSelector from 'ee/vue_merge_request_widget/components/checks/security_policy_violations_selector.vue';
import { WARN_MODE, EXCEPTION_MODE } from 'ee/vue_merge_request_widget/components/checks/constants';

describe('SecurityPolicyViolationsSelector', () => {
  let wrapper;

  const createComponent = () => {
    wrapper = shallowMountExtended(SecurityPolicyViolationsSelector);
  };

  beforeEach(() => {
    createComponent();
  });

  it('renders both selector options', () => {
    const headers = wrapper.findAllByTestId('header');

    expect(headers).toHaveLength(2);
    expect(headers.at(0).text()).toBe('Exception Bypass (pre-approved)');
    expect(headers.at(1).text()).toBe('Warn mode (bypass eligible)');
  });

  it('renders descriptions for both options', () => {
    const descriptions = wrapper.findAllByTestId('description');

    expect(descriptions.at(0).text()).toContain('You have been granted bypass permissions');
    expect(descriptions.at(1).text()).toContain('These policies are configured in warn mode');
  });

  it('renders continue buttons for both options', () => {
    const buttons = wrapper.findAllComponents(GlButton);

    expect(buttons).toHaveLength(2);
    [0, 1].forEach((index) => {
      expect(buttons.at(index).text()).toBe('Continue');
      expect(buttons.at(index).props('category')).toBe('primary');
      expect(buttons.at(index).props('variant')).toBe('confirm');
    });
  });

  it.each`
    index | mode
    ${0}  | ${EXCEPTION_MODE}
    ${1}  | ${WARN_MODE}
  `('emits select event with mode when button is clicked', ({ index, mode }) => {
    const buttons = wrapper.findAllComponents(GlButton);

    buttons.at(index).vm.$emit('click');

    expect(wrapper.emitted('select')).toEqual([[mode]]);
  });
});
