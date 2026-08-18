import { GlAlert, GlModal } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import ConfirmationModal from 'ee/admin/application_settings/security_and_compliance/components/confirmation_modal.vue';

describe('ConfirmationModal', () => {
  let wrapper;

  const createComponent = () => {
    wrapper = shallowMountExtended(ConfirmationModal, {});
  };

  const findAlert = () => wrapper.findComponent(GlAlert);
  const findModal = () => wrapper.findComponent(GlModal);

  describe('rendering', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders the modal with correct props', () => {
      const modal = findModal();
      expect(modal.exists()).toBe(true);
      expect(modal.props('title')).toBe('Change group');
    });

    it('displays the modal alert', () => {
      expect(wrapper.text()).toContain(
        'This will disconnect your top-level compliance and security policy group, and all the frameworks it shares, from all other top-level groups.',
      );
      expect(wrapper.text()).toContain(
        'Are you sure you want to change the compliance and security policy group?',
      );
      expect(findAlert().exists()).toBe(true);
    });

    it('emits change event on confirm', async () => {
      await findModal().vm.$emit('primary');
      expect(wrapper.emitted('change')).toHaveLength(1);
    });
  });
});
