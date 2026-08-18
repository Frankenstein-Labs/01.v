import { GlModal } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import UpstreamClearCacheModal from 'ee/packages_and_registries/virtual_registries/components/common/upstreams/clear_cache_modal.vue';

describe('UpstreamClearCacheModal', () => {
  let wrapper;

  const defaultProps = {
    visible: false,
    upstreamName: 'Test Upstream',
  };

  const findModal = () => wrapper.findComponent(GlModal);

  const createComponent = ({ props = {} } = {}) => {
    wrapper = shallowMountExtended(UpstreamClearCacheModal, {
      propsData: {
        ...defaultProps,
        ...props,
      },
    });
  };

  describe('component rendering', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders modal with correct props', () => {
      expect(findModal().props()).toMatchObject({
        visible: false,
        modalId: 'clear-upstream-cache-modal',
        size: 'sm',
        title: 'Clear cache for Test Upstream?',
        actionPrimary: {
          text: 'Clear cache',
          attributes: {
            variant: 'danger',
            category: 'primary',
          },
        },
        actionCancel: {
          text: 'Cancel',
        },
      });
    });

    it('renders correct modal content', () => {
      expect(findModal().text()).toBe(
        'Clearing the cache deletes all cached packages for this upstream and re-fetch them from the source. If the upstream is unavailable or misconfigured, jobs might fail. Are you sure you want to continue?',
      );
    });
  });

  describe('when visible', () => {
    beforeEach(() => {
      createComponent({ props: { visible: true } });
    });

    it('shows modal', () => {
      expect(findModal().props('visible')).toBe(true);
    });
  });

  describe('events', () => {
    beforeEach(() => {
      createComponent();
    });

    it('emits canceled event when modal is canceled', () => {
      findModal().vm.$emit('canceled');

      expect(wrapper.emitted('canceled')).toHaveLength(1);
    });

    it('emits primary event when modal primary action is triggered', () => {
      findModal().vm.$emit('primary');

      expect(wrapper.emitted('primary')).toHaveLength(1);
    });

    it('emits change event when modal visibility changes', () => {
      findModal().vm.$emit('change', true);

      expect(wrapper.emitted('change')).toEqual([[true]]);
    });
  });
});
