import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import StreamDestinationEditorGcpFields from 'ee/audit_events/components/stream/stream_destination_editor_gcp_fields.vue';
import { newStreamDestination } from '../../mock_data';
import { mockGcpTypeDestination } from '../../mock_data/consolidated_api';

describe('StreamDestinationEditorGcpFields', () => {
  let wrapper;

  const createComponent = ({ props = {} } = {}) => {
    wrapper = shallowMountExtended(StreamDestinationEditorGcpFields, {
      propsData: {
        ...props,
      },
    });
  };

  const findAddNewPrivateKeyButton = () => wrapper.findComponentByTestId('private-key-add-button');
  const findCancelNewPrivateKeyButton = () => wrapper.findByTestId('private-key-cancel-button');
  const findProjectId = () => wrapper.findComponentByTestId('project-id');
  const findClientEmail = () => wrapper.findComponentByTestId('client-email');
  const findLogId = () => wrapper.findComponentByTestId('log-id');
  const findPrivateKey = () => wrapper.findByTestId('private-key');

  describe('when creating a new destination', () => {
    beforeEach(() => {
      createComponent({
        props: {
          value: newStreamDestination,
          isEditing: false,
        },
      });
    });

    it('does not show add new private key button', () => {
      expect(findAddNewPrivateKeyButton().exists()).toBe(false);
    });
  });
  describe('when editing a destination', () => {
    beforeEach(() => {
      createComponent({
        props: {
          value: mockGcpTypeDestination[0],
          isEditing: true,
        },
      });
    });

    it('renders the fields correctly', () => {
      expect(findProjectId().props('value')).toBe('google-project-id-name');
      expect(findClientEmail().props('value')).toBe('clientEmail@example.com');
      expect(findLogId().props('value')).toBe('gcp-log-id-name');
      expect(wrapper.text()).toContain(
        'Use the Google Cloud console to view the private key. To change the private key, replace it with a new private key.',
      );
      expect(findAddNewPrivateKeyButton().props('disabled')).toBe(false);
      expect(findCancelNewPrivateKeyButton().exists()).toBe(false);
      expect(findPrivateKey().exists()).toBe(false);
    });

    it('displays private key input when add new private key button is clicked', async () => {
      await findAddNewPrivateKeyButton().vm.$emit('click');

      expect(findAddNewPrivateKeyButton().props('disabled')).toBe(true);
      expect(findCancelNewPrivateKeyButton().exists()).toBe(true);
      expect(findPrivateKey().exists()).toBe(true);
    });
  });
});
