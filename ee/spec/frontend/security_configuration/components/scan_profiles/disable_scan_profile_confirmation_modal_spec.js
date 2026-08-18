import { GlModal } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import DisableScanProfileConfirmationModal from 'ee/security_configuration/components/scan_profiles/disable_scan_profile_confirmation_modal.vue';

describe('DisableScanProfileConfirmationModal', () => {
  let wrapper;

  const createComponent = (props = {}) => {
    wrapper = shallowMountExtended(DisableScanProfileConfirmationModal, {
      propsData: {
        visible: true,
        scannerName: 'Secret Push Protection',
        ...props,
      },
      stubs: {
        GlModal,
      },
    });

    return wrapper;
  };

  const findModal = () => wrapper.findComponent(GlModal);

  describe('modal rendering', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders modal with correct props', () => {
      const modal = findModal();
      expect(modal.exists()).toBe(true);
      expect(modal.props()).toMatchObject({
        visible: true,
        modalId: 'disable-scanner-confirmation-modal',
        size: 'sm',
      });
    });

    it('renders modal title with scanner name', () => {
      const modal = findModal();
      expect(modal.props('title')).toBe('Disable Secret Push Protection');
    });

    it('renders confirmation message with scanner name', () => {
      expect(wrapper.text()).toContain(
        'You are about to disable Secret Push Protection for this project. Are you sure you want to proceed?',
      );
    });

    it('renders primary action with danger variant', () => {
      const modal = findModal();
      expect(modal.props('actionPrimary')).toMatchObject({
        text: 'Disable Secret Push Protection',
        attributes: {
          variant: 'danger',
        },
      });
    });

    it('renders cancel action', () => {
      const modal = findModal();
      expect(modal.props('actionCancel')).toMatchObject({
        text: 'Cancel',
      });
    });
  });

  describe('visibility prop', () => {
    it('passes visible true to modal when prop is true', () => {
      createComponent({ visible: true });

      expect(findModal().props('visible')).toBe(true);
    });

    it('passes visible false to modal when prop is false', () => {
      createComponent({ visible: false });

      expect(findModal().props('visible')).toBe(false);
    });
  });

  describe('scanner name prop', () => {
    it('updates modal title when scanner name changes', () => {
      createComponent({ scannerName: 'Test Scanner' });

      expect(findModal().props('title')).toBe('Disable Test Scanner');
      expect(wrapper.text()).toContain('You are about to disable Test Scanner');
    });
  });

  describe('event handling', () => {
    beforeEach(() => {
      createComponent();
    });

    it('emits confirm event when primary action is clicked', () => {
      findModal().vm.$emit('primary');

      expect(wrapper.emitted('confirm')).toHaveLength(1);
    });

    it('emits cancel event when modal is hidden', () => {
      findModal().vm.$emit('hidden');

      expect(wrapper.emitted('cancel')).toHaveLength(1);
    });
  });
});
