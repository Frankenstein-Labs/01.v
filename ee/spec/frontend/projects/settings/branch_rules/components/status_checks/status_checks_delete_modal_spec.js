import { GlSprintf, GlModal } from '@gitlab/ui';
import StatusCheckDeleteModal from 'ee/projects/settings/branch_rules/components/status_checks/status_checks_delete_modal.vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { stubComponent } from 'helpers/stub_component';
import { statusChecksRulesMock } from '../mock_data';

describe('Status checks in branch rules enterprise edition', () => {
  let wrapper;

  const createComponent = () => {
    wrapper = shallowMountExtended(StatusCheckDeleteModal, {
      propsData: {
        selectedStatusCheck: statusChecksRulesMock[0],
      },
      stubs: {
        GlModal: stubComponent(GlModal, {
          props: ['modalModule', 'modalId', 'actionPrimary', 'actionCancel'],
        }),
        GlSprintf,
      },
    });
  };

  const findModal = () => wrapper.findComponent(GlModal);

  beforeEach(() => createComponent());

  describe('renders correctly', () => {
    it('renders a confirmation message with selected status check name', async () => {
      await createComponent();
      expect(findModal().props()).toEqual(
        expect.objectContaining({
          modalId: 'statusChecksDeleteModal',
          actionPrimary: {
            text: 'Delete status check',
            attributes: { variant: 'danger', loading: false },
          },
          actionCancel: { text: 'Cancel' },
        }),
      );
      expect(findModal().text()).toContain('You are about to delete the test status check.');
    });

    it('calls remove status check when the modal is submitted', () => {
      findModal().vm.$emit('ok', { preventDefault: jest.fn() });
      expect(wrapper.emitted('delete-status-check')).toEqual([['123']]);
    });

    it('calls to close the modal when cancels', () => {
      findModal().vm.$emit('change');
      expect(wrapper.emitted('close-modal')).toEqual([[]]);
    });
  });
});
