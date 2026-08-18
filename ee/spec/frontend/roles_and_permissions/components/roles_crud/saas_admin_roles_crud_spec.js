import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import adminRolesQuery from 'ee/roles_and_permissions/graphql/admin_roles.query.graphql';
import RolesCrud from 'ee/roles_and_permissions/components/roles_crud/roles_crud.vue';
import SaasAdminRolesCrud from 'ee/roles_and_permissions/components/roles_crud/saas_admin_roles_crud.vue';
import { showRolesFetchError } from 'ee/roles_and_permissions/components/roles_crud/utils';
import { saasAdminRolesResponse, newAdminRoleOption } from '../../mock_data';

Vue.use(VueApollo);

jest.mock('ee/roles_and_permissions/components/roles_crud/utils', () => ({
  ...jest.requireActual('ee/roles_and_permissions/components/roles_crud/utils'),
  showRolesFetchError: jest.fn(),
}));

describe('SaasAdminRolesCrud component', () => {
  let wrapper;

  const defaultRolesQueryHandler = jest.fn().mockResolvedValue(saasAdminRolesResponse);

  const createComponent = ({
    rolesQueryHandler = defaultRolesQueryHandler,
    newRolePath = 'new/role/path',
  } = {}) => {
    wrapper = shallowMountExtended(SaasAdminRolesCrud, {
      apolloProvider: createMockApollo([[adminRolesQuery, rolesQueryHandler]]),
      provide: { newRolePath },
    });

    return waitForPromises();
  };

  const findRolesCrud = () => wrapper.findComponent(RolesCrud);

  describe('on page load', () => {
    beforeEach(() => {
      createComponent();
    });

    it('fetches SaaS admin roles', () => {
      expect(defaultRolesQueryHandler).toHaveBeenCalledTimes(1);
    });

    it('shows roles crud component', () => {
      expect(findRolesCrud().props()).toMatchObject({ roles: {}, loading: true });
    });
  });

  it.each`
    newRolePath        | expectedOptions
    ${null}            | ${[]}
    ${'new/role/path'} | ${[newAdminRoleOption]}
  `(
    'passes expected new role options to roles crud when newRolePath is $newRolePath',
    ({ newRolePath, expectedOptions }) => {
      createComponent({ newRolePath });

      expect(findRolesCrud().props('newRoleOptions')).toEqual(expectedOptions);
    },
  );

  describe('when query is finished', () => {
    beforeEach(() => createComponent());

    it('passes roles to roles crud component', () => {
      expect(findRolesCrud().props('roles')).toEqual(saasAdminRolesResponse.data);
    });

    it('shows roles crud component as not loading', () => {
      expect(findRolesCrud().props('loading')).toBe(false);
    });

    it('refetches query when role is deleted', () => {
      findRolesCrud().vm.$emit('deleted');

      expect(defaultRolesQueryHandler).toHaveBeenCalledTimes(2);
    });
  });

  describe('when query throws an error', () => {
    beforeEach(() => createComponent({ rolesQueryHandler: jest.fn().mockRejectedValue() }));

    it('shows fetch error', () => {
      expect(showRolesFetchError).toHaveBeenCalledTimes(1);
    });
  });
});
