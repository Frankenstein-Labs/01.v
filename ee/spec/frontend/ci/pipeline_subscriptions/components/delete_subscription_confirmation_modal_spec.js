import { GlModal } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import DeleteSubscriptionConfirmationModal from 'ee/ci/pipeline_subscriptions/components/delete_subscription_confirmation_modal.vue';

describe('Delete Subscription Confirmation Modal', () => {
  let wrapper;

  const findModal = () => wrapper.findComponent(GlModal);

  const createComponent = () => {
    wrapper = shallowMountExtended(DeleteSubscriptionConfirmationModal, {
      propsData: {
        isModalVisible: true,
      },
    });
  };

  beforeEach(() => {
    createComponent();
  });

  it('displays modal', () => {
    expect(findModal().exists()).toBe(true);
  });

  it('emits delete-confirmed event', () => {
    findModal().vm.$emit('primary');

    expect(wrapper.emitted('delete-confirmed')).toEqual([[]]);
  });

  it('emits hide event', () => {
    findModal().vm.$emit('hidden');

    expect(wrapper.emitted('hide')).toEqual([[]]);
  });
});
