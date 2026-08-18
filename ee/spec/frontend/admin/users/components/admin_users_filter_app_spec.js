import { GlFilteredSearch } from '@gitlab/ui';
import { shallowMount } from '@vue/test-utils';
import AdminUsersFilterApp from '~/admin/users/components/admin_users_filter_app.vue';
import { ADMIN_ROLE_TOKEN } from 'ee_jest/admin/users/mock_data';

describe('AdminUsersFilterApp', () => {
  let wrapper;

  const createComponent = ({ customRoles = true, readAdminRole = true }) => {
    wrapper = shallowMount(AdminUsersFilterApp, {
      provide: {
        glLicensedFeatures: { customRoles },
        glFeatures: {},
        glAbilities: { readAdminRole },
      },
    });
  };

  const findAvailableTokens = () =>
    wrapper.findComponent(GlFilteredSearch).props('availableTokens');

  it.each`
    customRoles | readAdminRole
    ${false}    | ${true}
    ${true}     | ${false}
  `(
    'does not include admin role token when customRoles = $customRoles, readAdminRole = $readAdminRole',
    ({ customRoles, readAdminRole }) => {
      createComponent({ customRoles, readAdminRole });

      expect(findAvailableTokens()).not.toContainEqual(ADMIN_ROLE_TOKEN);
    },
  );

  it(`includes admin role token when customRoles = true and readAdminRole = true`, () => {
    createComponent({ customRoles: true, readAdminRole: true });

    expect(findAvailableTokens()).toContainEqual(ADMIN_ROLE_TOKEN);
  });
});
