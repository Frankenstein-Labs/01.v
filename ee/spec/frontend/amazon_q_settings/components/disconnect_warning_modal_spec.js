import { GlModal } from '@gitlab/ui';
import { shallowMount } from '@vue/test-utils';
import DisconnectWarningModal from 'ee/amazon_q_settings/components/disconnect_warning_modal.vue';

describe('ee/amazon_q_settings/components/disconnect_warning_modal.vue', () => {
  let changeSpy;
  let wrapper;

  const createWrapper = (attrs = {}) => {
    wrapper = shallowMount(DisconnectWarningModal, {
      attrs: {
        visible: false,
        ...attrs,
      },
      listeners: {
        change: changeSpy,
      },
    });
  };

  const findModal = () => wrapper.findComponent(GlModal);

  beforeEach(() => {
    changeSpy = jest.fn();
  });

  describe('default', () => {
    beforeEach(() => {
      createWrapper();
    });

    it('renders modal', () => {
      expect(findModal().props()).toMatchObject({
        modalId: 'amazon-q-disconnect-warning-modal-1',
        title: expect.stringContaining('Are you sure?'),
        actionPrimary: {
          text: "Remove IAM role's ARN",
          attributes: { variant: 'danger' },
        },
        actionCancel: {
          text: 'Cancel',
        },
        visible: false,
      });
    });

    it('renders modal text', () => {
      expect(findModal().text()).toContain('If this is what you want');
    });

    it('passes through listeners', () => {
      expect(changeSpy).not.toHaveBeenCalled();

      findModal().vm.$emit('change', {});

      expect(changeSpy).toHaveBeenCalledWith({});
    });
  });

  it('passes through attributes', () => {
    createWrapper({ visible: true });

    expect(findModal().props('visible')).toBe(true);
  });
});
