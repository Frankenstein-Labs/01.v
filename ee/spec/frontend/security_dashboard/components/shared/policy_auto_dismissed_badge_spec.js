import { GlPopover, GlBadge } from '@gitlab/ui';
import { shallowMount } from '@vue/test-utils';
import PolicyAutoDismissedBadge from 'ee/security_dashboard/components/shared/policy_auto_dismissed_badge.vue';

describe('Policy auto-dismissed badge component', () => {
  let wrapper;
  const createWrapper = () => {
    return shallowMount(PolicyAutoDismissedBadge);
  };

  beforeEach(() => {
    wrapper = createWrapper();
  });

  const findBadge = () => wrapper.findComponent(GlBadge);
  const findPopover = () => wrapper.findComponent(GlPopover);

  describe('icon badge', () => {
    it('should render correctly', () => {
      expect(findBadge().props()).toMatchObject({
        icon: 'clear-all',
        variant: 'neutral',
      });
    });

    it('should have correct attributes', () => {
      expect(findBadge().attributes()).toMatchObject({
        'aria-label': 'Auto-dismissed by a security policy',
      });
    });
  });

  describe('popover', () => {
    it('should have a wrapping div as target', () => {
      expect(findPopover().props('target')()).toBe(wrapper.element);
    });

    it('renders the title', () => {
      expect(findPopover().props('title')).toBe('Auto-dismissed by a security policy');
    });

    it('renders the description', () => {
      expect(findPopover().attributes('content')).toBe(
        'This vulnerability was auto-dismissed by a security policy.',
      );
    });
  });
});
