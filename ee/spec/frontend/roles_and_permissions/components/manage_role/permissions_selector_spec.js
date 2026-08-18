import { GlAlert, GlSprintf, GlLink } from '@gitlab/ui';
import Vue from 'vue';
import VueApollo from 'vue-apollo';
import createMockApollo from 'helpers/mock_apollo_helper';
import PermissionsSelector from 'ee/roles_and_permissions/components/manage_role/permissions_selector.vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import waitForPromises from 'helpers/wait_for_promises';
import memberPermissionsQuery from 'ee/roles_and_permissions/graphql/member_role_permissions.query.graphql';
import adminPermissionsQuery from 'ee/roles_and_permissions/graphql/admin_role/role_permissions.query.graphql';
import CrudComponent from '~/vue_shared/components/crud_component.vue';
import PermissionCategory from 'ee/roles_and_permissions/components/manage_role/permission_category.vue';
import { mockPermissionsResponse, mockDefaultPermissions } from '../../mock_data';

Vue.use(VueApollo);

describe('Permissions Selector component', () => {
  let wrapper;

  const defaultAvailablePermissionsHandler = jest.fn().mockResolvedValue(mockPermissionsResponse);

  const createComponent = ({
    mountFn = shallowMountExtended,
    permissions = [],
    permissionsQuery = memberPermissionsQuery,
    isValid = true,
    baseAccessLevel = null,
    availablePermissionsHandler = defaultAvailablePermissionsHandler,
    isAdminRole = false,
  } = {}) => {
    wrapper = mountFn(PermissionsSelector, {
      propsData: { permissions, isValid, baseAccessLevel },
      provide: { isAdminRole },
      apolloProvider: createMockApollo([[permissionsQuery, availablePermissionsHandler]]),
      stubs: { GlSprintf, CrudComponent },
    });

    return waitForPromises();
  };

  const findCrudComponent = () => wrapper.findComponent(CrudComponent);
  const findPermissionsSelectedMessage = () => wrapper.findByTestId('permissions-selected-message');
  const findAlert = () => wrapper.findComponent(GlAlert);
  const findLearnMore = () => wrapper.findByTestId('learn-more');
  const findLearnMoreLink = () => findLearnMore().findComponent(GlLink);
  const findAllPermissionCategories = () => wrapper.findAllComponents(PermissionCategory);
  const findValidationMessage = () => wrapper.findByTestId('validation-message');

  const selectPermission = (value) => {
    findAllPermissionCategories().at(0).vm.$emit('change', { value });
  };

  const expectSelectedPermissions = (expected) => {
    const permissions = wrapper.emitted('change')[0][0];

    expect(permissions.sort()).toEqual(expected.sort());
  };

  describe('learn more description', () => {
    beforeEach(() => createComponent());

    it('shows text', () => {
      expect(findLearnMore().text()).toBe('Learn more about available custom permissions.');
    });

    it('shows link', () => {
      expect(findLearnMoreLink().text()).toBe('available custom permissions');
      expect(findLearnMoreLink().props()).toMatchObject({
        href: '/help/user/custom_roles/abilities',
        target: '_blank',
      });
    });
  });

  describe('available permissions', () => {
    describe('when loading', () => {
      beforeEach(() => {
        createComponent();
      });

      it('calls the query', () => {
        expect(defaultAvailablePermissionsHandler).toHaveBeenCalledTimes(1);
      });

      it('shows the crud component as busy', () => {
        expect(findCrudComponent().props('isLoading')).toBe(true);
      });

      it('does not show the permissions selected message', () => {
        expect(findPermissionsSelectedMessage().exists()).toBe(false);
      });

      it('does not show the error message', () => {
        expect(findAlert().exists()).toBe(false);
      });
    });

    describe('after data is loaded', () => {
      beforeEach(() => createComponent({ baseAccessLevel: 'DEVELOPER' }));

      it('shows permission categories', () => {
        expect(findAllPermissionCategories()).toHaveLength(2);
      });

      it.each`
        name                        | index
        ${'Source code management'} | ${0}
        ${'Other'}                  | ${1}
      `('shows $name category', ({ name, index }) => {
        expect(findAllPermissionCategories().at(index).props()).toMatchObject({
          category: expect.objectContaining({ name }),
          baseAccessLevel: 'DEVELOPER',
        });
      });

      it('shows the permissions selected message', () => {
        expect(findPermissionsSelectedMessage().text()).toBe('4 of 8 permissions selected');
      });

      it('does not show the error message', () => {
        expect(findAlert().exists()).toBe(false);
      });
    });

    describe('on query error', () => {
      beforeEach(() => {
        const availablePermissionsHandler = jest.fn().mockRejectedValue();
        return createComponent({ availablePermissionsHandler });
      });

      it('shows the error message', () => {
        expect(findAlert().text()).toBe('Could not fetch available permissions.');
      });

      it('does not show permission categories', () => {
        expect(findAllPermissionCategories()).toHaveLength(0);
      });

      it('does not show the permissions selected message', () => {
        expect(findPermissionsSelectedMessage().exists()).toBe(false);
      });
    });
  });

  describe('dependent permissions', () => {
    it.each`
      permission | expected
      ${'A'}     | ${['A']}
      ${'B'}     | ${['A', 'B']}
      ${'C'}     | ${['A', 'B', 'C']}
      ${'D'}     | ${['A', 'B', 'C', 'D']}
      ${'E'}     | ${['E', 'F']}
      ${'F'}     | ${['E', 'F']}
      ${'G'}     | ${['A', 'B', 'C', 'G']}
    `('selects $expected when $permission is selected', async ({ permission, expected }) => {
      await createComponent();
      selectPermission(permission);

      expectSelectedPermissions(expected);
    });

    it.each`
      permission | expected
      ${'A'}     | ${['E', 'F', 'READ_CODE']}
      ${'B'}     | ${['A', 'E', 'F', 'READ_CODE']}
      ${'C'}     | ${['A', 'B', 'E', 'F', 'READ_CODE']}
      ${'D'}     | ${['A', 'B', 'C', 'E', 'F', 'G', 'READ_CODE']}
      ${'E'}     | ${['A', 'B', 'C', 'D', 'G', 'READ_CODE']}
      ${'F'}     | ${['A', 'B', 'C', 'D', 'G', 'READ_CODE']}
      ${'G'}     | ${['A', 'B', 'C', 'D', 'E', 'F', 'READ_CODE']}
    `(
      'selects $expected when all permissions start off selected and $permission is unselected',
      async ({ permission, expected }) => {
        const permissions = mockDefaultPermissions.map((p) => p.value);
        await createComponent({ permissions });
        // Uncheck the permission by removing it from all permissions.
        selectPermission(permission);

        expectSelectedPermissions(expected);
      },
    );
  });

  describe('validation state', () => {
    it('shows error message when isValid prop is false', () => {
      createComponent({ isValid: false });

      expect(findValidationMessage().text()).toBe('Select at least one permission.');
    });

    it('does not show error message when isValid prop is true', () => {
      createComponent({ isValid: true });

      expect(findValidationMessage().exists()).toBe(false);
    });
  });

  describe('for admin role', () => {
    beforeEach(() =>
      createComponent({ isAdminRole: true, permissionsQuery: adminPermissionsQuery }),
    );

    it('calls the admin permissions query', () => {
      expect(defaultAvailablePermissionsHandler).toHaveBeenCalledTimes(1);
    });

    it('does not show learn more description', () => {
      expect(findLearnMore().exists()).toBe(false);
    });
  });
});
