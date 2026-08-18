import { GlPopover, GlBadge } from '@gitlab/ui';
import { shallowMount } from '@vue/test-utils';
import PolicyViolationBadge from 'ee/security_dashboard/components/shared/policy_violation_badge.vue';

describe('Policy Violation badge component', () => {
  let wrapper;
  const createWrapper = () => {
    return shallowMount(PolicyViolationBadge);
  };

  beforeEach(() => {
    wrapper = createWrapper();
  });

  const findPopover = () => wrapper.findComponent(GlPopover);

  it('should have an icon badge', () => {
    expect(wrapper.findComponent(GlBadge).props()).toMatchObject({
      icon: 'flag',
      variant: 'neutral',
    });
  });

  describe('popover', () => {
    it('should have a wrapping div as target', () => {
      expect(findPopover().props('target')()).toBe(wrapper.element);
    });

    it('renders the title', () => {
      expect(findPopover().props('title')).toBe('Detected by a security policy');
    });

    it('renders the description', () => {
      expect(findPopover().attributes('content')).toBe(
        'This vulnerability was bypassed by a user in a merge request. The user accepted the risk in a security policy configured to use warn mode.',
      );
    });
  });
});
