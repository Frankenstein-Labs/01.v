import { GlBadge } from '@gitlab/ui';
import { mount } from '@vue/test-utils';
import { nextTick } from 'vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import TierBadge from 'ee/vue_shared/components/tier_badge/tier_badge.vue';
import TierBadgePopover from 'ee/vue_shared/components/tier_badge/tier_badge_popover.vue';
import { mockTracking } from 'helpers/tracking_helper';

describe('TierBadge', () => {
  let wrapper;

  const mockProvide = {
    primaryCtaLink: '/primary',
    secondaryCtaLink: '/secondary',
    isProject: true,
    trialDuration: 30,
  };
  const findBadge = () => wrapper.findByTestId('tier-badge');
  const createComponent = ({ props = {} } = {}) => {
    wrapper = shallowMountExtended(TierBadge, {
      propsData: {
        ...props,
      },
    });
  };

  describe('tracking', () => {
    it('tracks render on mount', () => {
      const trackingSpy = mockTracking(undefined, undefined, jest.spyOn);

      createComponent();
      expect(trackingSpy).toHaveBeenCalledWith(undefined, 'render_badge', { label: 'tier_badge' });
    });

    it('tracks when popover shown', () => {
      const trackingSpy = mockTracking(undefined, undefined, jest.spyOn);
      createComponent();

      findBadge().trigger('mouseover');
      expect(trackingSpy).toHaveBeenCalledWith(undefined, 'render_flyout', { label: 'tier_badge' });
    });
  });

  describe('with default props', () => {
    it('renders the default tier', () => {
      createComponent();

      expect(wrapper.text()).toBe('Free');
    });
  });

  describe('when tier is passed in', () => {
    it('renders the passed in tier', () => {
      createComponent({ props: { tier: 'Ultimate' } });

      expect(wrapper.text()).toBe('Ultimate');
    });
  });

  describe('multiple instances', () => {
    it('creates two tier badge instances and verifies popover works for both', async () => {
      const wrapper1 = mount(TierBadge, { propsData: { tier: 'Premium' }, provide: mockProvide });
      const wrapper2 = mount(TierBadge, { propsData: { tier: 'Ultimate' }, provide: mockProvide });

      await nextTick();

      expect(wrapper1.text()).toContain('Premium');
      expect(wrapper2.text()).toContain('Ultimate');

      const popover1 = wrapper1.findComponent(TierBadgePopover);
      const popover2 = wrapper2.findComponent(TierBadgePopover);

      expect(popover1.exists()).toBe(true);
      expect(popover2.exists()).toBe(true);

      expect(popover1.props('tier')).toBe('Premium');
      expect(popover2.props('tier')).toBe('Ultimate');

      expect(popover1.props('target')).toBe(wrapper1.findComponent(GlBadge).element);
      expect(popover2.props('target')).toBe(wrapper2.findComponent(GlBadge).element);
    });
  });
});
