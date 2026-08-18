import { GlAlert } from '@gitlab/ui';
import { shallowMount } from '@vue/test-utils';
import { MountingPortal } from 'portal-vue';
import { stubComponent } from 'helpers/stub_component';
import DisconnectSuccessAlert from 'ee/amazon_q_settings/components/disconnect_success_alert.vue';

describe('ee/amazon_q_settings/components/disconnect_warning_modal.vue', () => {
  let dismissSpy;
  let wrapper;

  const createWrapper = () => {
    wrapper = shallowMount(DisconnectSuccessAlert, {
      listeners: {
        dismiss: dismissSpy,
      },
      stubs: {
        MountingPortal: stubComponent(MountingPortal, { name: 'MountingPortal' }),
      },
    });
  };

  const findMountingPortal = () => wrapper.findComponent(MountingPortal);
  const findAlert = () => findMountingPortal().findComponent(GlAlert);

  beforeEach(() => {
    dismissSpy = jest.fn();
  });

  describe('default', () => {
    beforeEach(() => {
      createWrapper();
    });

    it('renders mounting portal', () => {
      expect(findMountingPortal().attributes()).toMatchObject({
        'mount-to': '.flash-container',
        name: 'amazon-q-disconnect-success-alert',
      });
    });

    it('renders alert', () => {
      expect(findAlert().props()).toMatchObject({
        dismissible: true,
        title: 'GitLab Duo with Amazon Q has been successfully disconnected',
        variant: 'success',
      });
    });

    it('renders alert text', () => {
      expect(findAlert().find('p').text()).toEqual(
        'To completely remove GitLab Duo with Amazon Q, update the following in AWS:',
      );
    });

    it('passes through dismiss', async () => {
      expect(dismissSpy).not.toHaveBeenCalled();

      await findAlert().vm.$emit('dismiss');

      expect(dismissSpy).toHaveBeenCalled();
    });
  });
});
