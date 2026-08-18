import { GlBadge, GlIcon, GlLoadingIcon, GlPopover } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import ScaVrBadge from 'ee/security_dashboard/components/shared/sca_vr_badge.vue';

describe('ScaVrBadge', () => {
  let wrapper;

  const createWrapper = (props = {}) => {
    wrapper = shallowMountExtended(ScaVrBadge, {
      propsData: { ...props },
    });
  };

  const findBadge = () => wrapper.findComponent(GlBadge);
  const findLoader = () => wrapper.findComponent(GlLoadingIcon);
  const findIcon = () => wrapper.findComponent(GlIcon);
  const findPopover = () => wrapper.findComponent(GlPopover);
  const findResolveButton = () => wrapper.findComponentByTestId('sca-vr-resolve-button');

  describe('available state', () => {
    beforeEach(() => createWrapper());

    it('renders the available badge with the VR icon and a popover', () => {
      expect(findBadge().attributes('data-testid')).toBe('sca-vr-badge');
      expect(findBadge().props('variant')).toBe('tier');
      expect(findIcon().props('name')).toBe('tanuki-ai');
      expect(findPopover().exists()).toBe(true);
      expect(findLoader().exists()).toBe(false);
    });

    it('emits "resolve" when the resolve button is clicked', () => {
      findResolveButton().vm.$emit('click', { stopPropagation: () => {} });

      expect(wrapper.emitted('resolve')).toHaveLength(1);
    });
  });

  describe('in-progress state', () => {
    beforeEach(() => createWrapper({ pendingTrigger: true }));

    it('renders the in-progress badge with a spinner and no popover', () => {
      expect(findBadge().attributes('data-testid')).toBe('sca-vr-in-progress-badge');
      expect(findBadge().props('variant')).toBe('info');
      expect(findLoader().exists()).toBe(true);
      expect(findPopover().exists()).toBe(false);
    });
  });
});
