import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { GlCollapsibleListbox, GlListboxItem, GlAlert, GlIcon, GlSkeletonLoader } from '@gitlab/ui';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import AdminRoleDropdown from 'ee/admin/users/components/user_type/admin_role_dropdown.vue';
import adminRolesQuery from 'ee/admin/users/graphql/admin_roles.query.graphql';
import { visitUrl } from '~/lib/utils/url_utility';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import { adminRoles, adminRole, ldapRole } from '../mock_data';

Vue.use(VueApollo);
jest.mock('~/lib/utils/url_utility');

describe('AdminRoleDropdown component', () => {
  let wrapper;

  const getAdminRolesHandler = (roles = []) =>
    jest.fn().mockResolvedValue({ data: { adminMemberRoles: { nodes: roles } } });
  const defaultAdminRolesHandler = getAdminRolesHandler(adminRoles);

  const createWrapper = ({
    adminRolesHandler = defaultAdminRolesHandler,
    role = adminRole,
  } = {}) => {
    wrapper = mountExtended(AdminRoleDropdown, {
      apolloProvider: createMockApollo([[adminRolesQuery, adminRolesHandler]]),
      provide: { manageRolesPath: 'manage/roles/path' },
      propsData: { role },
    });

    return waitForPromises();
  };

  const findDropdown = () => wrapper.findComponent(GlCollapsibleListbox);
  const findDropdownItemAt = (index) => wrapper.findAllComponents(GlListboxItem).at(index);
  const findPermissions = () => wrapper.findByTestId('permissions');
  const findPermissionAt = (index) => findPermissions().findAll('li').at(index);
  const getHiddenInputValue = () => wrapper.find('input[type="hidden"]').element.value;
  const findAlert = () => wrapper.findComponent(GlAlert);
  const findSkeletonLoader = () => wrapper.findComponent(GlSkeletonLoader);

  describe('on page load before roles are loaded', () => {
    beforeEach(() => {
      createWrapper();
    });

    it('shows dropdown', () => {
      expect(findDropdown().props()).toMatchObject({
        headerText: 'Change access',
        resetButtonLabel: 'Manage roles',
        infiniteScrollLoading: true,
      });
    });

    it('runs admin roles query', () => {
      expect(defaultAdminRolesHandler).toHaveBeenCalledTimes(1);
    });

    it('shows loading spinner in dropdown', () => {
      expect(findDropdown().props('infiniteScrollLoading')).toBe(true);
    });

    it('does not show empty roles message in dropdown footer', () => {
      expect(findDropdown().text()).not.toContain('Create admin role to populate this list.');
    });
  });

  describe('when there is no role', () => {
    beforeEach(() => {
      createWrapper({ role: null });
    });

    it('uses default text behavior for dropdown button', () => {
      expect(findDropdown().props('toggleText')).toBe('');
    });

    it('does not show permissions skeleton loader', () => {
      // No role means that No access is selected by default, which does not have permissions to show.
      expect(findSkeletonLoader().exists()).toBe(false);
    });

    it('does not show permissions after roles are loaded', async () => {
      await waitForPromises();

      expect(findPermissions().exists()).toBe(false);
    });
  });

  describe('when there is a role', () => {
    beforeEach(() => {
      createWrapper({ role: adminRole });
    });

    it('shows role name in dropdown button', () => {
      expect(findDropdown().props('toggleText')).toBe('Custom admin role');
    });

    it('enables dropdown', () => {
      expect(findDropdown().props('disabled')).toBe(false);
    });

    it('shows permissions loading skeleton', () => {
      expect(findSkeletonLoader().exists()).toBe(true);
    });
  });

  it('disables dropdown when the role is LDAP assigned', () => {
    createWrapper({ role: ldapRole });

    expect(findDropdown().props('disabled')).toBe(true);
  });

  describe('after roles are loaded', () => {
    beforeEach(() => createWrapper());

    it('does not show permissions skeleton loader', () => {
      expect(findSkeletonLoader().exists()).toBe(false);
    });

    it('shows roles in dropdown', () => {
      const roles = adminRoles.map((role) => ({
        ...role,
        value: getIdFromGraphQLId(role.id),
        text: role.name,
      }));

      expect(findDropdown().props('items')).toEqual([
        {
          text: 'No access',
          options: [{ text: 'No access', value: -1 }],
          textSrOnly: true,
        },
        { text: 'Custom admin roles', options: roles },
      ]);
    });

    it('shows permissions for selected role', () => {
      expect(findPermissionAt(0).text()).toBe('A');
      expect(findPermissionAt(1).text()).toBe('B');
    });

    it('clears dropdown button text override', () => {
      expect(findDropdown().props('toggleText')).toBe('');
    });

    it('navigates to manage roles page when Manage roles button is clicked', () => {
      findDropdown().vm.$emit('reset');

      expect(visitUrl).toHaveBeenCalledWith('manage/roles/path');
    });

    describe.each(adminRoles)('when $name role is selected', (role) => {
      beforeEach(() => {
        const index = adminRoles.indexOf(role) + 1;
        return findDropdownItemAt(index).trigger('click');
      });

      it('sets hidden input value to role ID', () => {
        expect(getHiddenInputValue()).toBe(getIdFromGraphQLId(role.id).toString());
      });

      describe('permissions list', () => {
        describe.each(role.enabledPermissions.nodes)('for permission $name', (permission) => {
          const index = role.enabledPermissions.nodes.indexOf(permission);

          it('shows check icon', () => {
            expect(findPermissionAt(index).findComponent(GlIcon).props()).toMatchObject({
              name: 'check',
              variant: 'success',
            });
          });

          it('shows permission name', () => {
            expect(findPermissionAt(index).text()).toBe(permission.name);
          });
        });
      });
    });

    describe('No access option', () => {
      it('shows text', () => {
        expect(findDropdownItemAt(0).text()).toBe('No access');
      });

      it('does not bold text', () => {
        expect(findDropdownItemAt(0).find('div').classes('gl-font-bold')).toBe(false);
      });

      describe('when No access is selected', () => {
        beforeEach(() => findDropdownItemAt(0).trigger('click'));

        it('sets hidden input value to empty string', () => {
          expect(getHiddenInputValue()).toBe('');
        });

        it('does not show permissions list', () => {
          expect(findPermissions().exists()).toBe(false);
        });
      });
    });

    describe.each(adminRoles)('$name option', (role) => {
      let nameDiv;
      let descriptionDiv;

      beforeEach(() => {
        // +1 because the first option is "No access".
        const index = adminRoles.indexOf(role) + 1;
        const itemDivs = findDropdownItemAt(index).findAll('div');
        nameDiv = itemDivs.at(0);
        descriptionDiv = itemDivs.at(1);
      });

      it('shows text', () => {
        expect(nameDiv.text()).toBe(role.name);
      });

      it('bolds text and clamps line count', () => {
        expect(nameDiv.classes()).toEqual(['gl-line-clamp-2', 'gl-font-bold']);
      });

      it('shows description', () => {
        expect(descriptionDiv.text()).toBe(role.description);
      });

      it('shows description with expected classes', () => {
        expect(descriptionDiv.classes()).toEqual([
          'gl-mt-2',
          'gl-line-clamp-2',
          'gl-text-sm',
          'gl-text-subtle',
        ]);
      });
    });
  });

  describe('when there are no roles', () => {
    it('shows empty roles message in dropdown footer', async () => {
      await createWrapper({ adminRolesHandler: getAdminRolesHandler([]) });

      expect(findDropdown().text()).toContain('Create admin role to populate this list.');
    });
  });

  describe('when roles could not be loaded', () => {
    beforeEach(() => {
      createWrapper({ adminRolesHandler: jest.fn().mockRejectedValue() });
      findDropdown().vm.$emit('shown');
      return waitForPromises();
    });

    it('shows alert', () => {
      expect(findAlert().text()).toBe('Could not load custom admin roles.');
      expect(findAlert().props()).toMatchObject({
        dismissible: false,
        variant: 'danger',
      });
    });

    it('does not show dropdown', () => {
      expect(findDropdown().exists()).toBe(false);
    });
  });
});
