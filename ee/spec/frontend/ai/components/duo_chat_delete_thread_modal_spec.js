import { GlModal } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import DuoChatDeleteThreadModal from 'ee/ai/components/duo_chat_delete_thread_modal.vue';

describe('DuoChatDeleteThreadModal', () => {
  let wrapper;

  const findModal = () => wrapper.findComponent(GlModal);

  const createComponent = (props = {}) => {
    wrapper = shallowMountExtended(DuoChatDeleteThreadModal, {
      propsData: {
        ...props,
      },
    });
  };

  beforeEach(() => {
    createComponent();
  });

  it('renders the modal with the confirmation title and body', () => {
    expect(findModal().props('title')).toBe('Delete chat');
    expect(wrapper.text()).toContain('Are you sure you want to delete this chat?');
  });

  it('passes the visibility through to the modal', () => {
    createComponent({ visible: true });

    expect(findModal().props('visible')).toBe(true);
  });

  it('renders a danger primary action that is not loading by default', () => {
    expect(findModal().props('actionPrimary')).toMatchObject({
      text: 'Delete',
      attributes: { variant: 'danger', loading: false },
    });
    expect(findModal().props('actionCancel')).toMatchObject({
      text: 'Cancel',
      attributes: { disabled: false },
    });
  });

  it('marks the primary action as loading and disables cancel when loading', () => {
    createComponent({ loading: true });

    expect(findModal().props('actionPrimary').attributes).toMatchObject({ loading: true });
    expect(findModal().props('actionCancel').attributes).toMatchObject({ disabled: true });
  });

  it('emits confirm and keeps the modal open when the primary action is clicked', () => {
    const event = { preventDefault: jest.fn() };
    findModal().vm.$emit('primary', event);

    expect(event.preventDefault).toHaveBeenCalled();
    expect(wrapper.emitted('confirm')).toHaveLength(1);
  });

  it('emits change when the modal visibility changes', () => {
    findModal().vm.$emit('change', false);

    expect(wrapper.emitted('change')).toEqual([[false]]);
  });
});
