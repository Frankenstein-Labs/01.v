import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { GlButton } from '@gitlab/ui';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import SyncAllButton from 'ee/roles_and_permissions/components/ldap_sync/sync_all_button.vue';
import adminRolesLdapSyncMutation from 'ee/roles_and_permissions/graphql/ldap_sync/admin_roles_ldap_sync.graphql';
import { createMockDirective, getBinding } from 'helpers/vue_mock_directive';
import { createAlert } from '~/alert';

const mockAlertDismiss = jest.fn();
jest.mock('~/alert', () => ({
  createAlert: jest.fn().mockImplementation(() => ({
    dismiss: mockAlertDismiss,
  })),
}));

Vue.use(VueApollo);

describe('SyncAllButton component', () => {
  let wrapper;

  const getSyncMutationHandler = (error) =>
    jest.fn().mockResolvedValue({
      data: { adminRolesLdapSync: { errors: error ? [error] : [] } },
    });
  const defaultSyncMutationHandler = getSyncMutationHandler();

  const createWrapper = ({ syncMutationHandler = defaultSyncMutationHandler } = {}) => {
    wrapper = mountExtended(SyncAllButton, {
      apolloProvider: createMockApollo([[adminRolesLdapSyncMutation, syncMutationHandler]]),
      directives: {
        GlTooltip: createMockDirective('gl-tooltip'),
      },
    });
  };

  const findButton = () => wrapper.findComponent(GlButton);
  const findButtonTooltip = () => getBinding(wrapper.find('div').element, 'gl-tooltip');

  const clickButton = () => {
    findButton().vm.$emit('click');
    return waitForPromises();
  };

  describe('sync button', () => {
    beforeEach(() => createWrapper());

    it('shows button', () => {
      expect(findButton().text()).toBe('Sync all');
      expect(findButton().props()).toMatchObject({
        icon: 'retry',
        loading: false,
        disabled: false,
      });
    });

    it('does not have tooltip text', () => {
      expect(findButtonTooltip().value).toBe('');
    });
  });

  describe('when sync button is clicked', () => {
    beforeEach(() => {
      createWrapper();
      clickButton();
    });

    it('shows button as loading', () => {
      expect(findButton().text()).toBe('Sync all');
      expect(findButton().props()).toMatchObject({
        loading: true,
        disabled: false,
        icon: '', // The loading icon will show, so we hide the retry icon.
      });
    });

    it('does not have tooltip text', () => {
      expect(findButtonTooltip().value).toBe('');
    });

    it('runs sync mutation', () => {
      expect(defaultSyncMutationHandler).toHaveBeenCalledTimes(1);
    });
  });

  describe('when sync mutation is successful', () => {
    beforeEach(() => {
      createWrapper();
      return clickButton();
    });

    it('shows button as disabled', () => {
      expect(findButton().text()).toBe('Sync scheduled');
      expect(findButton().props()).toMatchObject({
        loading: false,
        disabled: true,
        icon: 'retry',
      });
    });

    it('has tooltip', () => {
      expect(findButtonTooltip()).toMatchObject({
        value: 'The LDAP sync has been scheduled. Refresh the page to view sync status.',
        modifiers: { d0: true },
      });
    });

    it('shows alert', () => {
      expect(createAlert).toHaveBeenCalledTimes(1);
      expect(createAlert).toHaveBeenCalledWith({
        variant: 'info',
        message: 'The LDAP sync has been scheduled. Refresh the page to view sync status.',
      });
    });
  });

  describe.each`
    phrase                                        | syncMutationHandler
    ${'when sync mutation response has an error'} | ${getSyncMutationHandler('some error')}
    ${'when sync mutation throws an error'}       | ${jest.fn().mockRejectedValue()}
  `('$phrase', ({ syncMutationHandler }) => {
    beforeEach(() => {
      createWrapper({ syncMutationHandler });
      return clickButton();
    });

    it('shows button as enabled', () => {
      expect(findButton().text()).toBe('Sync all');
      expect(findButton().props()).toMatchObject({
        icon: 'retry',
        loading: false,
        disabled: false,
      });
    });

    it('shows error alert', () => {
      expect(createAlert).toHaveBeenCalledTimes(1);
      expect(createAlert).toHaveBeenCalledWith({
        message: 'Failed to schedule LDAP sync. Please retry syncing.',
      });
    });

    it('does not have tooltip text', () => {
      expect(findButtonTooltip().value).toBe('');
    });

    it('dismisses alert when button is clicked again', () => {
      clickButton();

      expect(mockAlertDismiss).toHaveBeenCalledTimes(1);
    });
  });
});
