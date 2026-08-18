import { shallowMount } from '@vue/test-utils';
import SamlReloadModal from 'ee/saml_sso/components/saml_reload_modal.vue';
import { getExpiringSamlSession } from 'ee/saml_sso/saml_sessions';
import SessionExpireModal from '~/authentication/sessions/components/session_expire_modal.vue';
import waitForPromises from 'helpers/wait_for_promises';

jest.useFakeTimers();

jest.mock('ee/saml_sso/saml_sessions', () => ({
  getExpiringSamlSession: jest.fn(),
}));

describe('SamlReloadModal', () => {
  let wrapper;

  const samlSessionsUrl = '/test.json';

  const createComponent = () => {
    wrapper = shallowMount(SamlReloadModal, {
      propsData: { samlProviderId: 1, samlSessionsUrl },
    });
  };

  const findModal = () => wrapper.findComponent(SessionExpireModal);

  describe('when there is no expiring SAML session', () => {
    it('does not show the modal', () => {
      createComponent();

      expect(findModal().exists()).toBe(false);
    });
  });

  describe('when there is an expired SAML sessions', () => {
    it('shows the modal', async () => {
      getExpiringSamlSession.mockResolvedValue({ timeRemainingMs: 0 });
      createComponent();
      await waitForPromises();

      expect(findModal().props()).toMatchObject({
        message:
          'Please, reload the page and sign in again, if necessary. To avoid data loss, if you have unsaved edits, dismiss the modal and copy the unsaved text before refreshing the page.',
        sessionTimeout: Date.now(),
        title: 'Your SAML session has expired',
      });
    });
  });
});
