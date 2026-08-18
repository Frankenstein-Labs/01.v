import Vue from 'vue';
import VueApollo from 'vue-apollo';
import createMockApollo from 'helpers/mock_apollo_helper';
import createMemberRoleMutation from 'ee/roles_and_permissions/graphql/create_member_role.mutation.graphql';
import createAdminRoleMutation from 'ee/roles_and_permissions/graphql/admin_role/create_role.mutation.graphql';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import RoleCreate from 'ee/roles_and_permissions/components/manage_role/role_create.vue';
import RoleForm from 'ee/roles_and_permissions/components/manage_role/role_form.vue';
import { visitUrl } from '~/lib/utils/url_utility';
import waitForPromises from 'helpers/wait_for_promises';
import { createAlert } from '~/alert';

jest.mock('~/lib/utils/url_utility');

const mockAlertDismiss = jest.fn();
jest.mock('~/alert', () => ({
  createAlert: jest.fn().mockImplementation(() => ({
    dismiss: mockAlertDismiss,
  })),
}));

Vue.use(VueApollo);

const getCreateMutationHandler = (error) =>
  jest.fn().mockResolvedValue({ data: { memberRoleCreate: { errors: error ? [error] : [] } } });

describe('RoleCreate', () => {
  let wrapper;

  const defaultCreateMutationHandler = getCreateMutationHandler();

  const createComponent = ({
    createMutation = createMemberRoleMutation,
    createMutationHandler = defaultCreateMutationHandler,
    isAdminRole = false,
  } = {}) => {
    wrapper = shallowMountExtended(RoleCreate, {
      propsData: {
        groupFullPath: 'test-group',
        listPagePath: 'http://list/page/path',
      },
      provide: { isAdminRole },
      apolloProvider: createMockApollo([[createMutation, createMutationHandler]]),
    });
  };

  const findRoleForm = () => wrapper.findComponent(RoleForm);

  const submitForm = (data) => {
    findRoleForm().vm.$emit('submit', data);
    return waitForPromises();
  };

  it('shows the role form', () => {
    createComponent();

    expect(findRoleForm().props()).toMatchObject({
      title: 'Create member role',
      submitText: 'Create role',
      showBaseRole: true,
      busy: false,
    });
  });

  it('redirects back to list page when form is cancelled', () => {
    createComponent();
    findRoleForm().vm.$emit('cancel');

    expect(visitUrl).toHaveBeenCalledTimes(1);
    expect(visitUrl).toHaveBeenCalledWith('http://list/page/path');
  });

  describe('when the form is submitted', () => {
    beforeEach(() => {
      createComponent();
      submitForm({ a: '1' });
    });

    it('calls mutation with expected data', () => {
      expect(defaultCreateMutationHandler).toHaveBeenCalledTimes(1);
      expect(defaultCreateMutationHandler).toHaveBeenCalledWith({
        a: '1',
        groupPath: 'test-group',
      });
    });

    it('marks form as busy', () => {
      expect(findRoleForm().props('busy')).toBe(true);
    });

    describe('after role is created', () => {
      beforeEach(() => waitForPromises());

      it('redirects to list page', () => {
        expect(visitUrl).toHaveBeenCalledTimes(1);
        expect(visitUrl).toHaveBeenCalledWith('http://list/page/path');
      });

      it('keeps form as busy', () => {
        expect(findRoleForm().props('busy')).toBe(true);
      });
    });
  });

  describe.each`
    phrase                                 | createMutationHandler                     | message
    ${'when mutation returns an error'}    | ${getCreateMutationHandler('some error')} | ${'Failed to create role: some error'}
    ${'when there is an unexpected error'} | ${jest.fn().mockRejectedValue('error')}   | ${'Failed to create role.'}
  `('$phrase', ({ createMutationHandler, message }) => {
    beforeEach(() => {
      createComponent({ createMutationHandler });
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
    beforeEach(() =>
      createComponent({ isAdminRole: true, createMutation: createAdminRoleMutation }),
    );

    it('shows the role form', () => {
      expect(findRoleForm().props()).toMatchObject({
        title: 'Create admin role',
        showBaseRole: false,
      });
    });

    it('calls create admin role mutation', () => {
      wrapper.vm.saveRole({ a: '1' });

      expect(defaultCreateMutationHandler).toHaveBeenCalledTimes(1);
      expect(defaultCreateMutationHandler).toHaveBeenCalledWith(
        expect.objectContaining({ a: '1' }),
      );
    });
  });
});
