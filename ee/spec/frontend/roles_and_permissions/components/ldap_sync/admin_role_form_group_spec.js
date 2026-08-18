import { GlFormGroup, GlCollapsibleListbox, GlListboxItem } from '@gitlab/ui';
import VueApollo from 'vue-apollo';
import Vue from 'vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import AdminRoleFormGroup from 'ee/roles_and_permissions/components/ldap_sync/admin_role_form_group.vue';
import createMockApollo from 'helpers/mock_apollo_helper';
import adminRolesQuery from 'ee/admin/users/graphql/admin_roles.query.graphql';
import waitForPromises from 'helpers/wait_for_promises';
import { adminRoles } from 'ee_jest/admin/users/components/mock_data';
import { createAlert } from '~/alert';
import { glFormGroupStub } from './helpers';

jest.mock('~/alert');

Vue.use(VueApollo);

describe('AdminRoleDropdown component', () => {
  let wrapper;

  const getAdminRolesHandler = (nodes = adminRoles) =>
    jest.fn().mockResolvedValue({ data: { adminMemberRoles: { nodes } } });
  const defaultAdminRolesHandler = getAdminRolesHandler();

  const createWrapper = ({
    value,
    state = true,
    disabled = false,
    adminRolesHandler = defaultAdminRolesHandler,
  } = {}) => {
    wrapper = shallowMountExtended(AdminRoleFormGroup, {
      propsData: { value, state, disabled },
      apolloProvider: createMockApollo([[adminRolesQuery, adminRolesHandler]]),
      stubs: { GlFormGroup: glFormGroupStub, GlCollapsibleListbox },
    });

    return waitForPromises();
  };

  const findFormGroup = () => wrapper.findComponent(GlFormGroup);
  const findDropdown = () => wrapper.findComponent(GlCollapsibleListbox);
  const findDropdownItems = () => wrapper.findAllComponents(GlListboxItem);

  describe('on page load', () => {
    beforeEach(() => {
      createWrapper();
    });

    it('shows form group', () => {
      expect(findFormGroup().props()).toMatchObject({
        label: 'Custom admin role',
        invalidFeedback: 'This field is required',
      });
    });

    it('shows the dropdown', () => {
      expect(findDropdown().props()).toMatchObject({
        selected: null,
        items: [],
        category: 'secondary',
        variant: 'default',
        toggleText: 'Select a role',
        block: true,
        loading: true,
      });
    });

    it('runs admin roles query', () => {
      expect(defaultAdminRolesHandler).toHaveBeenCalledTimes(1);
    });

    it.each([true, false])('passes disabled prop with value %s to dropdown', async (disabled) => {
      await wrapper.setProps({ disabled });

      expect(findDropdown().props('disabled')).toBe(disabled);
    });
  });

  describe.each`
    state    | variant
    ${true}  | ${'default'}
    ${false} | ${'danger'}
  `('when state prop is $state', ({ state, variant }) => {
    beforeEach(() => createWrapper({ state }));

    it('passes state value to form group', () => {
      expect(findFormGroup().props('state')).toBe(state);
    });

    it('sets dropdown variant to $variant', () => {
      expect(findDropdown().props('variant')).toBe(variant);
    });
  });

  it('emits input event when dropdown item is selected', () => {
    createWrapper();
    findDropdown().vm.$emit('select', 'group1');

    expect(wrapper.emitted('input')[0][0]).toBe('group1');
  });

  describe('when value prop has a value', () => {
    beforeEach(() => createWrapper({ value: 'group1' }));

    it('passes value to dropdown', () => {
      expect(findDropdown().props('selected')).toBe('group1');
    });

    it('sets toggle text to empty string', () => {
      // Empty string makes the dropdown use its default behavior of showing the selected item's
      // text.
      expect(findDropdown().props('toggleText')).toBe('');
    });
  });

  describe('when admin role data is fetched', () => {
    beforeEach(() => createWrapper());

    it('enables dropdown', () => {
      expect(findDropdown().props('loading')).toBe(false);
    });

    it('passes fetched roles to dropdown', () => {
      expect(findDropdown().props('items')).toEqual([
        {
          value: 'gid://gitlab/MemberRole/1',
          text: 'Admin role 1',
          description: 'Admin role 1 description',
        },
        {
          value: 'gid://gitlab/MemberRole/2',
          text: 'Admin role 2',
          description: 'Admin role 2 description',
        },
      ]);
    });
  });

  describe('when role data could not be fetched', () => {
    beforeEach(() => createWrapper({ adminRolesHandler: jest.fn().mockRejectedValue() }));

    it('shows an error message', () => {
      expect(createAlert).toHaveBeenCalledWith({ message: 'Could not load custom admin roles.' });
    });
  });

  describe.each(adminRoles)('for role $name', (role) => {
    const index = adminRoles.indexOf(role);

    beforeEach(() => createWrapper());

    it('shows role name', () => {
      expect(findDropdownItems().at(index).text()).toContain(role.name);
    });

    it('shows role description', () => {
      expect(findDropdownItems().at(index).text()).toContain(role.description);
    });
  });
});
