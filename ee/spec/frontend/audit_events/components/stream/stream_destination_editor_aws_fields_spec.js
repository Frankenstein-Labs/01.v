import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import StreamDestinationEditorAwsFields from 'ee/audit_events/components/stream/stream_destination_editor_aws_fields.vue';
import { newStreamDestination } from '../../mock_data';
import { mockAwsTypeDestination } from '../../mock_data/consolidated_api';

describe('StreamDestinationEditorAwsFields', () => {
  let wrapper;

  const createComponent = ({ props = {} } = {}) => {
    wrapper = shallowMountExtended(StreamDestinationEditorAwsFields, {
      propsData: {
        ...props,
      },
    });
  };

  const findAddNewSecretAccessKeyButton = () =>
    wrapper.findComponentByTestId('secret-access-key-add-button');
  const findCancelNewSecretAccessKeyButton = () =>
    wrapper.findByTestId('secret-access-key-cancel-button');
  const findAccessKeyXid = () => wrapper.findComponentByTestId('access-key-xid');
  const findAwsRegion = () => wrapper.findComponentByTestId('aws-region');
  const findBucketName = () => wrapper.findComponentByTestId('bucket-name');
  const findSecretAccessKey = () => wrapper.findByTestId('secret-access-key');

  describe('when creating a new destination', () => {
    beforeEach(() => {
      createComponent({
        props: {
          value: newStreamDestination,
          isEditing: false,
        },
      });
    });

    it('does not show add new secret access key button', () => {
      expect(findAddNewSecretAccessKeyButton().exists()).toBe(false);
    });
  });
  describe('when editing a destination', () => {
    beforeEach(() => {
      createComponent({
        props: {
          value: mockAwsTypeDestination[0],
          isEditing: true,
        },
      });
    });

    it('renders the fields correctly', () => {
      expect(findAccessKeyXid().props('value')).toBe('myAwsAccessKey_needs_16_chars_min');
      expect(findAwsRegion().props('value')).toBe('us-test-1');
      expect(findBucketName().props('value')).toBe('bucket-name');
      expect(wrapper.text()).toContain(
        'Use the AWS console to view the secret access key. To change the secret access key, replace it with a new secret access key.',
      );
      expect(findAddNewSecretAccessKeyButton().props('disabled')).toBe(false);
      expect(findCancelNewSecretAccessKeyButton().exists()).toBe(false);
      expect(findSecretAccessKey().exists()).toBe(false);
    });

    it('displays secret access key input when add new secret access key button is clicked', async () => {
      await findAddNewSecretAccessKeyButton().vm.$emit('click');

      expect(findAddNewSecretAccessKeyButton().props('disabled')).toBe(true);
      expect(findCancelNewSecretAccessKeyButton().exists()).toBe(true);
      expect(findSecretAccessKey().exists()).toBe(true);
    });
  });
});
