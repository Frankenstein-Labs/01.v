import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { GlLoadingIcon, GlAlert } from '@gitlab/ui';
import createMockApollo from 'helpers/mock_apollo_helper';
import updateMemberRoleMutation from 'ee/roles_and_permissions/graphql/update_member_role.mutation.graphql';
import updateAdminRoleMutation from 'ee/roles_and_permissions/graphql/admin_role/update_role.mutation.graphql';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import RoleEdit from 'ee/roles_and_permissions/components/manage_role/role_edit.vue';
import RoleForm from 'ee/roles_and_permissions/components/manage_role/role_form.vue';
import memberRoleQuery from 'ee/roles_and_permissions/graphql/role_details/member_role.query.graphql';
import adminRoleQuery from 'ee/roles_and_permissions/graphql/admin_role/role.query.graphql';
import waitForPromises from 'helpers/wait_for_promises';
import { visitUrl } from '~/lib/utils/url_utility';
import { createAlert } from '~/alert';
import { getMemberRoleQueryResponse } from '../../mock_data';

jest.mock('~/lib/utils/url_utility');

const mockAlertDismiss = jest.fn();
jest.mock('~/alert', () => ({
  createAlert: jest.fn().mockImplementation(() => ({
    dismiss: mockAlertDismiss,
  })),
}));

Vue.use(VueApollo);

const getRoleQueryHandler = (role) => jest.fn().mockResolvedValue(getMemberRoleQueryResponse(role));

const getUpdateMutationHandler = (error) =>
  jest.fn().mockResolvedValue({ data: { memberRoleUpdate: { errors: error ? [error] : [] } } });

describe('RoleEdit', () => {
  let wrapper;

  const defaultRoleQueryHandler = getRoleQueryHandler();
  const defaultUpdateMutationHandler = getUpdateMutationHandler();

  const createComponent = ({
    roleQuery = memberRoleQuery,
    updateMutation = updateMemberRoleMutation,
    roleQueryHandler = defaultRoleQueryHandler,
    updateMutationHandler = defaultUpdateMutationHandler,
    isAdminRole = false,
  } = {}) => {
    wrapper = shallowMountExtended(RoleEdit, {
      propsData: {
        listPagePath: 'http://list/page/path',
        roleId: 5,
      },
      provide: { isAdminRole },
      apolloProvider: createMockApollo([
        [roleQuery, roleQueryHandler],
        [updateMutation, updateMutationHandler],
      ]),
    });

    return waitForPromises();
  };

  const findRoleForm = () => wrapper.findComponent(RoleForm);
  const findLoadingIcon = () => wrapper.findComponent(GlLoadingIcon);
  const findAlert = () => wrapper.findComponent(GlAlert);

  const submitForm = (data) => {
    findRoleForm().vm.$emit('submit', data);
    return waitForPromises();
  };

  describe('on page load', () => {
    beforeEach(() => {
      createComponent();
    });

    it('shows loading icon', () => {
      expect(findLoadingIcon().props('size')).toBe('lg');
    });

    it('does not show role form', () => {
      expect(findRoleForm().exists()).toBe(false);
    });
  });

  describe('after role is fetched', () => {
    beforeEach(() => createComponent());

    it('does not show loading icon', () => {
      expect(findLoadingIcon().exists()).toBe(false);
    });

    it('shows role form', () => {
      expect(findRoleForm().props()).toMatchObject({
        title: 'Edit member role',
        submitText: 'Save role',
        showBaseRole: true,
        busy: false,
      });
    });

    it('redirects back to list page when form is cancelled', () => {
      findRoleForm().vm.$emit('cancel');

      expect(visitUrl).toHaveBeenCalledTimes(1);
      expect(visitUrl).toHaveBeenCalledWith('http://list/page/path');
    });
  });

  describe('when role could not be fetched', () => {
    beforeEach(() => {
      createComponent({ roleQueryHandler: jest.fn().mockResolvedValue() });
      return waitForPromises();
    });

    it('shows an error alert', () => {
      expect(findAlert().text()).toBe('Failed to load custom role.');
      expect(findAlert().props()).toMatchObject({
        variant: 'danger',
        dismissible: false,
      });
    });

    it('does not show loading icon', () => {
      expect(findLoadingIcon().exists()).toBe(false);
    });

    it('does not show role form', () => {
      expect(findRoleForm().exists()).toBe(false);
    });
  });

  describe('when the form is submitted', () => {
    beforeEach(async () => {
      await createComponent();
      submitForm({ a: '1' });
    });

    it('calls mutation with expected data', () => {
      expect(defaultUpdateMutationHandler).toHaveBeenCalledTimes(1);
      expect(defaultUpdateMutationHandler).toHaveBeenCalledWith({
        id: 'gid://gitlab/MemberRole/5',
        a: '1',
      });
    });

    it('marks form as busy', () => {
      expect(findRoleForm().props('busy')).toBe(true);
    });

    describe('after role is saved', () => {
      beforeEach(() => waitForPromises());

      it('redirects to list page after role is saved', () => {
        expect(visitUrl).toHaveBeenCalledTimes(1);
        expect(visitUrl).toHaveBeenCalledWith('http://list/page/path');
      });

      it('keeps form as busy', () => {
        expect(findRoleForm().props('busy')).toBe(true);
      });
    });
  });

  describe('when user came from the details page', () => {
    beforeEach(() => {
      window.history.replaceState({}, '', '?from_details');
      return createComponent();
    });

    it('redirects back to details page after role is saved', async () => {
      await submitForm();

      expect(visitUrl).toHaveBeenCalledWith('role/path/1');
    });

    it('redirects back to details page when form is cancelled', () => {
      findRoleForm().vm.$emit('cancel');

      expect(visitUrl).toHaveBeenCalledWith('role/path/1');
    });
  });

  describe.each`
    phrase                                 | updateMutationHandler                     | message
    ${'when mutation returns an error'}    | ${getUpdateMutationHandler('some error')} | ${'Failed to save role: some error'}
    ${'when there is an unexpected error'} | ${jest.fn().mockRejectedValue('error')}   | ${'Failed to save role.'}
  `('$phrase', ({ updateMutationHandler, message }) => {
    beforeEach(async () => {
      await createComponent({ updateMutationHandler });
      return submitForm();
    });

    it('shows error message', () => {
      expect(createAlert).toHaveBeenCalledTimes(1);
      expect(createAlert).toHaveBeenCalledWith({ message });
    });

    it('marks form as not busy', () => {
      expect(findRoleForm().props('busy')).toBe(false);
    });

    it('dismisses previous alert when form is re-submitted', () => {
      findRoleForm().vm.$emit('submit');

      expect(mockAlertDismiss).toHaveBeenCalled();
    });
  });

  describe('for admin role', () => {
    beforeEach(() => {
      return createComponent({
        isAdminRole: true,
        roleQuery: adminRoleQuery,
        updateMutation: updateAdminRoleMutation,
      });
    });

    it('shows role form', () => {
      expect(findRoleForm().props()).toMatchObject({
        title: 'Edit admin role',
        showBaseRole: false,
      });
    });

    it('calls update admin role mutation', () => {
      wrapper.vm.saveRole({ a: '1' });

      expect(defaultUpdateMutationHandler).toHaveBeenCalledTimes(1);
      expect(defaultUpdateMutationHandler).toHaveBeenCalledWith({
        id: 'gid://gitlab/MemberRole/5',
        a: '1',
      });
    });
  });
});
