import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import instanceRolesQuery from 'ee/roles_and_permissions/graphql/instance_roles.query.graphql';
import RolesCrud from 'ee/roles_and_permissions/components/roles_crud/roles_crud.vue';
import InstanceRolesCrud from 'ee/roles_and_permissions/components/roles_crud/instance_roles_crud.vue';
import { showRolesFetchError } from 'ee/roles_and_permissions/components/roles_crud/utils';
import { instanceRolesResponse, newCustomRoleOption, newAdminRoleOption } from '../../mock_data';

Vue.use(VueApollo);

jest.mock('ee/roles_and_permissions/components/roles_crud/utils', () => ({
  ...jest.requireActual('ee/roles_and_permissions/components/roles_crud/utils'),
  showRolesFetchError: jest.fn(),
}));

describe('InstanceRolesCrud component', () => {
  let wrapper;

  const defaultRolesQueryHandler = jest.fn().mockResolvedValue(instanceRolesResponse);

  const createComponent = ({
    rolesQueryHandler = defaultRolesQueryHandler,
    newRolePath = 'new/role/path',
    customRoles = true,
  } = {}) => {
    wrapper = shallowMountExtended(InstanceRolesCrud, {
      apolloProvider: createMockApollo([[instanceRolesQuery, rolesQueryHandler]]),
      provide: {
        newRolePath,
        glLicensedFeatures: { customRoles },
      },
    });

    return waitForPromises();
  };

  const findRolesCrud = () => wrapper.findComponent(RolesCrud);

  describe('on page load', () => {
    beforeEach(() => {
      createComponent();
    });

    it('fetches instance roles', () => {
      expect(defaultRolesQueryHandler).toHaveBeenCalledTimes(1);
    });

    it('shows roles crud component', () => {
      expect(findRolesCrud().props()).toMatchObject({ roles: {}, loading: true });
    });
  });

  it.each`
    customRoles | includeCustomRoles
    ${true}     | ${true}
    ${false}    | ${false}
  `(
    'calls roles query with expected variables when customRoles = $customRoles',
    ({ customRoles, includeCustomRoles }) => {
      createComponent({ customRoles });

      expect(defaultRolesQueryHandler).toHaveBeenCalledWith({
        includeCustomRoles,
      });
    },
  );

  it.each`
    newRolePath        | customRoles | expectedOptions
    ${null}            | ${false}    | ${[]}
    ${null}            | ${true}     | ${[]}
    ${'new/role/path'} | ${false}    | ${[newCustomRoleOption]}
    ${'new/role/path'} | ${true}     | ${[newCustomRoleOption, newAdminRoleOption]}
  `(
    'passes expected new role options to roles crud when newRolePath = $newRolePath, customRoles = $customRoles',
    ({ newRolePath, customRoles, expectedOptions }) => {
      createComponent({ newRolePath, customRoles });

      expect(findRolesCrud().props('newRoleOptions')).toEqual(expectedOptions);
    },
  );

  describe('when query is finished', () => {
    beforeEach(() => createComponent());

    it('passes roles to roles crud component', () => {
      expect(findRolesCrud().props('roles')).toEqual(instanceRolesResponse.data);
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
