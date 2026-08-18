import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import { GlAlert, GlLink, GlButton, GlSprintf, GlModal } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import ldapAdminRoleLinksQuery from 'ee/roles_and_permissions/graphql/ldap_sync/ldap_admin_role_links.query.graphql';
import ldapAdminRoleLinkCreateMutation from 'ee/roles_and_permissions/graphql/ldap_sync/ldap_admin_role_link_create.mutation.graphql';
import ldapAdminRoleLinkDestroyMutation from 'ee/roles_and_permissions/graphql/ldap_sync/ldap_admin_role_link_destroy.mutation.graphql';
import LdapSyncCrud from 'ee/roles_and_permissions/components/ldap_sync/ldap_sync_crud.vue';
import LdapSyncItem from 'ee/roles_and_permissions/components/ldap_sync/ldap_sync_item.vue';
import SyncAllButton from 'ee/roles_and_permissions/components/ldap_sync/sync_all_button.vue';
import CrudComponent from '~/vue_shared/components/crud_component.vue';
import ConfirmActionModal from '~/vue_shared/components/confirm_action_modal.vue';
import CreateSyncForm from 'ee/roles_and_permissions/components/ldap_sync/create_sync_form.vue';
import { createAlert } from '~/alert';
import { ldapAdminRoleLinks } from '../../mock_data';

Vue.use(VueApollo);

const mockAlertDismiss = jest.fn();
jest.mock('~/alert', () => ({
  createAlert: jest.fn().mockImplementation(() => ({
    dismiss: mockAlertDismiss,
  })),
}));

describe('LdapSyncCrud component', () => {
  let wrapper;

  const getRoleLinksHandler = (nodes = ldapAdminRoleLinks) =>
    jest.fn().mockResolvedValue({ data: { ldapAdminRoleLinks: { nodes } } });
  const defaultRoleLinksHandler = getRoleLinksHandler();

  const getCreateHandler = (error) =>
    jest.fn().mockResolvedValue({
      data: { ldapAdminRoleLinkCreate: { errors: error ? [error] : [] } },
    });
  const defaultCreateHandler = getCreateHandler();

  const getDestroyHandler = (error) =>
    jest.fn().mockResolvedValue({
      data: { ldapAdminRoleLinkDestroy: { errors: error ? [error] : [] } },
    });
  const defaultDestroyHandler = getDestroyHandler();

  const createWrapper = ({
    roleLinksHandler = defaultRoleLinksHandler,
    createHandler = defaultCreateHandler,
    destroyHandler = defaultDestroyHandler,
  } = {}) => {
    wrapper = shallowMountExtended(LdapSyncCrud, {
      apolloProvider: createMockApollo([
        [ldapAdminRoleLinksQuery, roleLinksHandler],
        [ldapAdminRoleLinkCreateMutation, createHandler],
        [ldapAdminRoleLinkDestroyMutation, destroyHandler],
      ]),
      provide: { ldapUsersPath: 'ldap/users/path' },
      stubs: { CrudComponent, GlSprintf, ConfirmActionModal },
    });

    return waitForPromises();
  };

  const findAlert = () => wrapper.findComponent(GlAlert);
  const findCrudComponent = () => wrapper.findComponent(CrudComponent);
  const findCrudActions = () => wrapper.findByTestId('crud-actions');
  const findCrudBody = () => wrapper.findByTestId('crud-body');
  const findLdapUsersLink = () => findCrudActions().findComponent(GlLink);
  const findAddSyncButton = () => findCrudActions().findComponent(GlButton);
  const findSyncAllButton = () => wrapper.findComponent(SyncAllButton);
  const findRoleLinksList = () => findCrudBody().find('ul');
  const findRoleLinkItems = () => findRoleLinksList().findAllComponents(LdapSyncItem);
  const findDeleteModal = () => wrapper.findComponent(ConfirmActionModal);
  const findCreateSyncForm = () => wrapper.findComponent(CreateSyncForm);

  const openDeleteModal = () => {
    findRoleLinkItems().at(0).vm.$emit('delete');
    return nextTick();
  };

  const confirmDeleteModal = () => {
    findDeleteModal().findComponent(GlModal).vm.$emit('primary', { preventDefault: jest.fn() });
    return waitForPromises();
  };

  describe('crud component', () => {
    beforeEach(() => createWrapper());

    it('shows title', () => {
      expect(findCrudComponent().props('title')).toBe('Active synchronizations');
    });

    it('shows description', () => {
      expect(findCrudComponent().props('description')).toBe(
        'Automatically sync your LDAP directory to custom admin roles. For users matched to multiple LDAP syncs, the oldest sync entry will be used.',
      );
    });
  });

  describe('on page load', () => {
    beforeEach(() => {
      createWrapper();
    });

    it('calls ldap role links query', () => {
      expect(defaultRoleLinksHandler).toHaveBeenCalledTimes(1);
    });

    it('does not show alert', () => {
      expect(findAlert().exists()).toBe(false);
    });

    it('shows crud component as busy', () => {
      expect(findCrudComponent().props('isLoading')).toBe(true);
    });

    describe('crud actions', () => {
      it('does not show ldap users link', () => {
        expect(findLdapUsersLink().exists()).toBe(false);
      });

      it('does not show Sync all button', () => {
        expect(findSyncAllButton().exists()).toBe(false);
      });

      it('does not show Add Synchronization button', () => {
        expect(findAddSyncButton().exists()).toBe(false);
      });
    });

    it('does not show create sync form', () => {
      expect(findCreateSyncForm().exists()).toBe(false);
    });
  });

  describe('when ldap role links could not be loaded', () => {
    beforeEach(() => createWrapper({ roleLinksHandler: jest.fn().mockRejectedValue }));

    it('shows alert', () => {
      expect(findAlert().props()).toMatchObject({ variant: 'danger', dismissible: false });
      expect(findAlert().text()).toBe(
        'Could not load LDAP synchronizations. Please refresh the page to try again.',
      );
    });

    it('does not show crud component', () => {
      expect(findCrudComponent().exists()).toBe(false);
    });
  });

  describe('when there are no ldap role links', () => {
    beforeEach(() => createWrapper({ roleLinksHandler: getRoleLinksHandler([]) }));

    it('does not show alert', () => {
      expect(findAlert().exists()).toBe(false);
    });

    it('does not show role links list', () => {
      expect(findRoleLinksList().exists()).toBe(false);
    });

    it('shows zero for the count', () => {
      expect(findCrudComponent().props('count')).toBe(0);
    });

    it('shows no synchronizations message', () => {
      expect(findCrudBody().text()).toBe(
        'No active LDAP synchronizations. Add synchronization to connect your LDAP directory with custom admin roles.',
      );
    });

    describe('crud actions', () => {
      it('does not show ldap users link', () => {
        expect(findLdapUsersLink().exists()).toBe(false);
      });

      it('does not show Sync all button', () => {
        expect(findSyncAllButton().exists()).toBe(false);
      });

      it('shows Add Synchronization button', () => {
        expect(findAddSyncButton().exists()).toBe(true);
      });
    });
  });

  describe('when there are ldap role links', () => {
    beforeEach(() => createWrapper());

    it('does not show alert', () => {
      expect(findAlert().exists()).toBe(false);
    });

    it('does not show no synchronizations message', () => {
      expect(findCrudBody().text()).not.toContain(
        'No active LDAP synchronizations. Add synchronization to connect your LDAP directory with custom admin roles.',
      );
    });

    it('shows the correct count', () => {
      expect(findCrudComponent().props('count')).toBe(2);
    });

    describe('crud actions', () => {
      it('shows ldap users link', () => {
        expect(findLdapUsersLink().text()).toBe('View LDAP synced users');
        expect(findLdapUsersLink().props('href')).toBe('ldap/users/path');
      });

      it('shows Sync all button', () => {
        expect(findSyncAllButton().exists()).toBe(true);
      });

      it('shows Add Synchronization button', () => {
        expect(findAddSyncButton().props('variant')).toBe('confirm');
        expect(findAddSyncButton().text()).toBe('Add synchronization');
      });
    });

    it('shows role links list', () => {
      expect(findRoleLinksList().exists()).toBe(true);
    });

    it('shows 2 role link items', () => {
      expect(findRoleLinkItems()).toHaveLength(2);
    });

    it.each(ldapAdminRoleLinks)('shows ldap sync item for role link $id', (roleLink) => {
      const index = ldapAdminRoleLinks.indexOf(roleLink);

      expect(findRoleLinkItems().at(index).props('roleLink')).toEqual(roleLink);
    });
  });

  describe('delete confirmation modal', () => {
    describe('common behavior', () => {
      beforeEach(async () => {
        await createWrapper();
        openDeleteModal();
      });

      it('shows modal', () => {
        expect(findDeleteModal().props()).toMatchObject({
          title: 'Remove LDAP synchronization',
          variant: 'confirm',
          actionText: 'Remove sync',
          modalId: 'remove-ldap-sync-modal',
        });
      });

      it('shows message in modal body', () => {
        expect(findDeleteModal().text()).toBe(
          'This removes automatic syncing with your LDAP server. Users will have their current role unassigned on the next sync. Are you sure you want to remove LDAP synchronization?',
        );
      });

      it('hides modal when modal is closed', async () => {
        findDeleteModal().vm.$emit('close');
        await nextTick();

        expect(findDeleteModal().exists()).toBe(false);
      });

      describe('when modal is confirmed', () => {
        beforeEach(() => confirmDeleteModal());

        it('calls delete mutation', () => {
          expect(defaultDestroyHandler).toHaveBeenCalledTimes(1);
          expect(defaultDestroyHandler).toHaveBeenCalledWith({
            id: 'gid://gitlab/Authz::LdapAdminRoleLink/1',
          });
        });

        it('refreshes sync list', () => {
          expect(defaultRoleLinksHandler).toHaveBeenCalledTimes(2);
        });
      });
    });

    it.each`
      phrase                                        | destroyHandler                                              | error
      ${'mutation throws error'}                    | ${jest.fn().mockRejectedValue(new Error('mutation error'))} | ${'mutation error'}
      ${'mutation succeeds but response has error'} | ${getDestroyHandler('response error')}                      | ${'response error'}
    `('shows error when $phrase', async ({ destroyHandler, error }) => {
      await createWrapper({ destroyHandler });
      await openDeleteModal();
      await confirmDeleteModal();

      expect(findDeleteModal().findComponent(GlAlert).text()).toBe(error);
    });
  });

  describe('when Add synchronization button is clicked', () => {
    beforeEach(async () => {
      await createWrapper();
      findAddSyncButton().vm.$emit('click');
    });

    it('shows create sync form', () => {
      expect(findCreateSyncForm().exists()).toBe(true);
    });

    it('hides create sync form when form is canceled', async () => {
      findCreateSyncForm().vm.$emit('cancel');
      await nextTick();

      expect(findCreateSyncForm().exists()).toBe(false);
    });

    describe.each([{ cn: 'group1' }, { filter: 'cn=group1,ou=groups,dc=example,dc=com' }])(
      'when form is submitted with %s',
      (data) => {
        const submitData = {
          provider: 'ldapmain',
          adminMemberRoleId: 'gid://gitlab/MemberRole/1',
          ...data,
        };

        beforeEach(() => {
          findCreateSyncForm().vm.$emit('submit', submitData);
        });

        it('calls create mutation', () => {
          expect(defaultCreateHandler).toHaveBeenCalledTimes(1);
          expect(defaultCreateHandler).toHaveBeenCalledWith(submitData);
        });

        it('marks form as busy', () => {
          expect(findCreateSyncForm().props('busy')).toBe(true);
        });

        it('does not close form', () => {
          expect(findCreateSyncForm().exists()).toBe(true);
        });

        describe('when mutation succeeds', () => {
          beforeEach(() => waitForPromises());

          it('closes form', () => {
            expect(findCreateSyncForm().exists()).toBe(false);
          });

          it('refreshes sync list', () => {
            expect(defaultRoleLinksHandler).toHaveBeenCalledTimes(2);
          });
        });
      },
    );

    describe.each`
      phrase                                 | createHandler
      ${'an exception'}                      | ${jest.fn().mockRejectedValue(new Error('some error'))}
      ${'an error in the mutation response'} | ${getCreateHandler('some error')}
    `('when create mutation fails due to $phrase', ({ createHandler }) => {
      beforeEach(async () => {
        await createWrapper({ createHandler });
        findAddSyncButton().vm.$emit('click');
        await nextTick();
        findCreateSyncForm().vm.$emit('submit');
        return waitForPromises();
      });

      it('shows error message', () => {
        expect(createAlert).toHaveBeenCalledTimes(1);
        expect(createAlert).toHaveBeenCalledWith({ message: 'some error' });
      });

      it('dismisses existing error message when form is submitted', () => {
        findCreateSyncForm().vm.$emit('submit');

        expect(mockAlertDismiss).toHaveBeenCalledTimes(1);
      });
    });
  });
});
