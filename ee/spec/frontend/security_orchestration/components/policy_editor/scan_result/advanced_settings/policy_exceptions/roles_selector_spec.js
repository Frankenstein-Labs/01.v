import { GlFormGroup } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import RolesSelector from 'ee/security_orchestration/components/policy_editor/scan_result/advanced_settings/policy_exceptions/roles_selector.vue';
import RoleSelect from 'ee/security_orchestration/components/shared/role_select.vue';
import { mockRoles } from 'ee_jest/security_orchestration/components/policy_editor/scan_result/advanced_settings/policy_exceptions/mocks';

describe('RolesSelector', () => {
  let wrapper;

  const createComponent = ({ selectedRoles = [] } = {}) => {
    wrapper = shallowMountExtended(RolesSelector, {
      propsData: {
        selectedRoles,
      },
    });
  };

  const findRoleSelect = () => wrapper.findComponent(RoleSelect);
  const findFormGroup = () => wrapper.findComponent(GlFormGroup);

  describe('component structure', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders GlFormGroup with correct attributes', () => {
      const formGroup = findFormGroup();

      expect(formGroup.exists()).toBe(true);
      expect(formGroup.attributes('id')).toBe('roles-list');
      expect(formGroup.attributes('label-for')).toBe('roles-list');
      expect(formGroup.classes()).toContain('gl-w-full');
      expect(formGroup.attributes('label')).toBe('Select role exceptions');
      expect(formGroup.attributes('description')).toBe('Choose which roles can bypass this policy');
    });

    it('renders UserSelect component with correct attributes', () => {
      const roleSelect = findRoleSelect();
      expect(roleSelect.exists()).toBe(true);
      expect(roleSelect.props('selected')).toEqual([]);
    });
  });

  describe('props handling', () => {
    it('passes empty array as selected when no selectedRoles provided', () => {
      createComponent();
      expect(findRoleSelect().props('selected')).toEqual([]);
    });

    it('converts selectedUsers to user IDs and passes to UserSelect', () => {
      createComponent({ selectedRoles: mockRoles });
      expect(findRoleSelect().props('selected')).toEqual(mockRoles);
    });

    it('handles empty selectedRoles array', () => {
      createComponent({ selectedRoles: [] });
      expect(findRoleSelect().props('selected')).toEqual([]);
    });

    it('handles selectedUsers with different user objects', () => {
      const customRoles = [
        { id: 1, role: 'test-role-1' },
        { id: 2, role: 'test-role-2' },
      ];
      const customRoleIds = customRoles.map(({ id }) => id);

      createComponent({ selectedRoles: customRoleIds });
      expect(findRoleSelect().props('selected')).toEqual(customRoleIds);
    });

    it('handles selectedUsers with mixed roles', () => {
      const mixedSelectedRoles = ['maintainer', 1];
      createComponent({ selectedRoles: mixedSelectedRoles });
      expect(findRoleSelect().props('selected')).toEqual(mixedSelectedRoles);
    });
  });

  describe('event handling', () => {
    beforeEach(() => {
      createComponent();
    });

    it('emits set-roles event when RoleSelect select-items event is triggered', async () => {
      const roleApproversData = { role_approvers: ['maintainer', 1] };

      await findRoleSelect().vm.$emit('select-items', roleApproversData);

      expect(wrapper.emitted('set-roles')).toEqual([
        [{ custom_roles: [{ id: 1 }], roles: ['maintainer'] }],
      ]);
    });

    it('emits set-users event with empty array when no users are selected', async () => {
      const roleApproversData = { role_approvers: [] };

      await findRoleSelect().vm.$emit('select-items', roleApproversData);

      expect(wrapper.emitted('set-roles')).toEqual([[{ custom_roles: [], roles: [] }]]);
    });

    it('handles select-items event with undefined role_approvers', async () => {
      const roleApproversData = {};

      await findRoleSelect().vm.$emit('select-items', roleApproversData);

      expect(wrapper.emitted('set-roles')).toEqual([[{ custom_roles: [], roles: [] }]]);
    });

    it('handles multiple select-items events correctly', async () => {
      const roleSelect = findRoleSelect();

      await roleSelect.vm.$emit('select-items', { role_approvers: [1] });
      await roleSelect.vm.$emit('select-items', { role_approvers: ['maintainer', 'developer'] });

      expect(wrapper.emitted('set-roles')).toEqual([
        [{ custom_roles: [{ id: 1 }], roles: [] }],
        [{ custom_roles: [], roles: ['maintainer', 'developer'] }],
      ]);
    });
  });
});
