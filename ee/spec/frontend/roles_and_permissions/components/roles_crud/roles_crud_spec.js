import { GlButton, GlSprintf, GlDisclosureDropdown, GlDisclosureDropdownItem } from '@gitlab/ui';
import { nextTick } from 'vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import waitForPromises from 'helpers/wait_for_promises';
import RolesCrud from 'ee/roles_and_permissions/components/roles_crud/roles_crud.vue';
import RolesTable from 'ee/roles_and_permissions/components/roles_table/roles_table.vue';
import DeleteRoleModal from 'ee/roles_and_permissions/components/delete_role_modal.vue';
import RolesExport from 'ee/roles_and_permissions/components/roles_table/roles_export.vue';
import CrudComponent from '~/vue_shared/components/crud_component.vue';
import { stubComponent, RENDER_ALL_SLOTS_TEMPLATE } from 'helpers/stub_component';
import { memberRoles, instanceRolesResponse } from '../../mock_data';

describe('RolesCrud component', () => {
  let wrapper;

  const mockToastShow = jest.fn();

  const createComponent = ({
    roles = instanceRolesResponse.data,
    loading = false,
    newRoleOptions = [],
    membersPermissionsDetailedExport = true,
    exportGroupMemberships = true,
  } = {}) => {
    wrapper = shallowMountExtended(RolesCrud, {
      propsData: { roles, loading, newRoleOptions },
      provide: {
        glFeatures: { membersPermissionsDetailedExport },
        glAbilities: { exportGroupMemberships },
      },
      stubs: {
        GlSprintf,
        CrudComponent: stubComponent(CrudComponent, { template: RENDER_ALL_SLOTS_TEMPLATE }),
        GlDisclosureDropdown,
      },
      mocks: { $toast: { show: mockToastShow } },
    });

    return waitForPromises();
  };

  const findRolesTable = () => wrapper.findComponent(RolesTable);
  const findCrudTitle = () => wrapper.findByTestId('slot-title');
  const findDeleteModal = () => wrapper.findComponent(DeleteRoleModal);
  const findRolesExport = () => wrapper.findComponent(RolesExport);
  const findDisclosureDropdown = () => wrapper.findComponent(GlDisclosureDropdown);
  const findDropdownItems = () => wrapper.findAllComponents(GlDisclosureDropdownItem);
  const findNewRoleButton = () => wrapper.findComponent(GlButton);

  describe('new role button', () => {
    describe('when there are no new role options', () => {
      beforeEach(() => createComponent());

      it('does not show new role button', () => {
        expect(findNewRoleButton().exists()).toBe(false);
      });

      it('does not show new role dropdown', () => {
        expect(findDisclosureDropdown().exists()).toBe(false);
      });
    });

    describe('when there is one new role option', () => {
      beforeEach(() =>
        createComponent({ newRoleOptions: [{ text: 'new role', href: 'abc/123' }] }),
      );

      it('shows new role button', () => {
        expect(findNewRoleButton().props('href')).toBe('abc/123');
        expect(findNewRoleButton().text()).toBe('New role');
      });

      it('does not show new role dropdown', () => {
        expect(findDisclosureDropdown().exists()).toBe(false);
      });
    });

    describe('when there are multiple new role options', () => {
      const newRoleOptions = [
        { text: 'Custom role', description: 'New custom role' },
        { text: 'Admin role', description: 'New admin role' },
      ];

      beforeEach(() => createComponent({ newRoleOptions }));

      it('does not show new role button', () => {
        expect(findNewRoleButton().exists()).toBe(false);
      });

      it('shows new role dropdown', () => {
        expect(findDisclosureDropdown().props()).toMatchObject({
          toggleText: 'New role',
          items: newRoleOptions,
          fluidWidth: true,
        });
      });

      it('shows expected number of dropdown items', () => {
        expect(findDropdownItems()).toHaveLength(newRoleOptions.length);
      });

      it.each(newRoleOptions)('shows dropdown item for option "$text"', (option) => {
        const index = newRoleOptions.indexOf(option);

        expect(findDropdownItems().at(index).text()).toContain(option.text);
        expect(findDropdownItems().at(index).text()).toContain(option.description);
      });
    });
  });

  describe('crud title', () => {
    it('shows Roles text in header', () => {
      createComponent();

      expect(findCrudTitle().text()).toContain('Roles');
    });

    it.each`
      standardRoles   | customRoles | adminRoles  | expectedCount
      ${[{}, {}, {}]} | ${[{}, {}]} | ${[{}]}     | ${'3 Default 2 Custom 1 Admin'}
      ${[]}           | ${[]}       | ${[]}       | ${'0 Default 0 Custom 0 Admin'}
      ${[{}]}         | ${[{}]}     | ${null}     | ${'1 Default 1 Custom'}
      ${[{}]}         | ${null}     | ${null}     | ${'1 Default'}
      ${null}         | ${null}     | ${[{}, {}]} | ${'2 Admin'}
    `(
      'shows role count: $expectedCount',
      ({ standardRoles, customRoles, adminRoles, expectedCount }) => {
        createComponent({
          roles: {
            standardRoles: { nodes: standardRoles },
            memberRoles: { nodes: customRoles },
            adminMemberRoles: { nodes: adminRoles },
          },
        });

        expect(findCrudTitle().text()).toContain(expectedCount);
      },
    );
  });

  describe('roles table', () => {
    it('passes roles to table', () => {
      const { data } = instanceRolesResponse;
      createComponent();

      expect(findRolesTable().props('roles')).toEqual([
        ...data.standardRoles.nodes,
        ...data.memberRoles.nodes,
        ...data.adminMemberRoles.nodes,
      ]);
    });

    it.each([true, false])('passes loading prop %s to table', (loading) => {
      createComponent({ loading });

      expect(findRolesTable().props('busy')).toBe(loading);
    });
  });

  describe('delete role modal', () => {
    beforeEach(() => createComponent());

    it('renders modal', () => {
      expect(findDeleteModal().exists()).toBe(true);
    });

    describe('when table wants to delete a role', () => {
      beforeEach(() => {
        findRolesTable().vm.$emit('delete-role', memberRoles[0]);
      });

      it('passes role to delete modal', () => {
        expect(findDeleteModal().props('role')).toBe(memberRoles[0]);
      });

      it('closes modal when modal emits close event', async () => {
        findDeleteModal().vm.$emit('close');
        await nextTick();

        expect(findDeleteModal().props('role')).toBe(null);
      });
    });

    describe('when modal finishes deleting a role', () => {
      beforeEach(() => {
        findDeleteModal().vm.$emit('deleted');
      });

      it('shows toast', () => {
        expect(mockToastShow).toHaveBeenCalledWith('Role successfully deleted.');
      });

      it('closes modal', () => {
        expect(findDeleteModal().props('role')).toBe(null);
      });

      it('emits deleted event', () => {
        expect(wrapper.emitted('deleted')).toHaveLength(1);
      });
    });
  });

  describe('roles export', () => {
    it('does not show roles export when user does not have the ability to export', () => {
      createComponent({ exportGroupMemberships: false });

      expect(findRolesExport().exists()).toBe(false);
    });

    it('does not show roles export when membersPermissionsDetailedExport feature flag is off', () => {
      createComponent({ membersPermissionsDetailedExport: false });

      expect(findRolesExport().exists()).toBe(false);
    });

    it('shows roles export when user has ability to export', () => {
      createComponent({ exportGroupMemberships: true });

      expect(findRolesExport().exists()).toBe(true);
    });
  });
});
