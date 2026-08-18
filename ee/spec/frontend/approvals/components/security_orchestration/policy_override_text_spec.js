import { GlLink, GlSprintf } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import PolicyOverrideText from 'ee/approvals/components/security_orchestration/policy_override_text.vue';

describe('PolicyOverrideText', () => {
  let wrapper;

  const policies = [
    { name: 'policy 1', editPath: 'link 1' },
    { name: 'policy 2', editPath: 'link 2' },
  ];

  const createComponent = (props = {}) => {
    wrapper = shallowMountExtended(PolicyOverrideText, {
      propsData: {
        policies: [policies[0]],
        ...props,
      },
      stubs: {
        GlSprintf,
      },
    });
  };

  const findAllLinks = () => wrapper.findAllComponents(GlLink);
  const findPolicyItem = (index) => wrapper.findByTestId(`policy-item-${index}`);

  describe('single policy', () => {
    describe('enforced mode', () => {
      beforeEach(() => {
        createComponent();
      });

      it('renders the correct text for a single enforced policy', () => {
        expect(wrapper.text()).toContain(
          'Approval settings might be affected by the rules in policy',
        );
        expect(wrapper.text()).toContain('policy 1');
        expect(wrapper.text()).toContain(
          'Enforcement of these properties is conditional on merge request policy violations',
        );
        expect(wrapper.text()).not.toContain('if the policy becomes enforced');
      });

      it('renders a link to the policy', () => {
        const link = findAllLinks().at(0);
        expect(link.attributes('href')).toBe('link 1');
        expect(link.text()).toBe('policy 1');
      });
    });

    describe('warn mode', () => {
      beforeEach(() => {
        createComponent({ isWarn: true });
      });

      it('renders the correct text for a single warn mode policy', () => {
        expect(wrapper.text()).toContain(
          'Approval settings might be affected by the rules in policy',
        );
        expect(wrapper.text()).toContain('policy 1');
      });

      it('renders a link to the policy', () => {
        const link = findAllLinks().at(0);
        expect(link.attributes('href')).toBe('link 1');
        expect(link.text()).toBe('policy 1');
      });
    });
  });

  describe('multiple policies', () => {
    describe('enforced mode', () => {
      beforeEach(() => {
        createComponent({ policies });
      });

      it('renders the correct text for multiple enforced policies', () => {
        expect(wrapper.text()).toContain(
          'Approval settings might be affected by rules in the following policies. These properties are only enforced when there are merge request policy violations:',
        );
        expect(wrapper.text()).not.toContain('if the policies are enforced');
      });

      it('renders a list of policy links', () => {
        expect(findPolicyItem(0).text()).toBe('policy 1');
        expect(findPolicyItem(1).text()).toBe('policy 2');
        expect(findPolicyItem(0).findComponent(GlLink).attributes('href')).toBe('link 1');
        expect(findPolicyItem(1).findComponent(GlLink).attributes('href')).toBe('link 2');
      });
    });

    describe('warn mode', () => {
      beforeEach(() => {
        createComponent({ policies, isWarn: true });
      });

      it('renders the correct text for multiple warn mode policies', () => {
        expect(wrapper.text()).toContain(
          'Approval settings might be affected by rules in the following policies if the policies change from warn mode to strictly enforced:',
        );
      });

      it('renders a list of policy links', () => {
        expect(findPolicyItem(0).text()).toBe('policy 1');
        expect(findPolicyItem(1).text()).toBe('policy 2');
        expect(findPolicyItem(0).findComponent(GlLink).attributes('href')).toBe('link 1');
        expect(findPolicyItem(1).findComponent(GlLink).attributes('href')).toBe('link 2');
      });
    });
  });

  describe('empty policies array', () => {
    it('does not render when policies array is empty', () => {
      createComponent({ policies: [] });
      expect(wrapper.text()).toBe('');
    });
  });
});
