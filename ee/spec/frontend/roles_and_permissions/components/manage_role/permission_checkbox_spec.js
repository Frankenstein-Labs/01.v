import { GlFormCheckbox, GlIcon, GlPopover, GlBadge, GlSprintf } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import PermissionCheckbox from 'ee/roles_and_permissions/components/manage_role/permission_checkbox.vue';
import { permissionWithoutChildren, permissionWithChildren } from '../../mock_data';

describe('Permissions Group component', () => {
  let wrapper;

  const createComponent = ({ permission = permissionWithoutChildren } = {}) => {
    wrapper = shallowMountExtended(PermissionCheckbox, {
      propsData: { permission, baseAccessLevel: 'DEVELOPER' },
      stubs: { GlSprintf },
    });
  };

  const findCheckbox = () => wrapper.findComponent(GlFormCheckbox);
  const findDescriptionIcon = () => wrapper.findComponent(GlIcon);
  const findPopover = () => wrapper.findComponent(GlPopover);
  const findBaseRoleBadge = () => wrapper.findComponent(GlBadge);
  const findChildPermissionsList = () => wrapper.find('ul');
  const findChildPermissionCheckboxes = () =>
    findChildPermissionsList().findAllComponents(PermissionCheckbox);

  describe('on page load', () => {
    beforeEach(() => createComponent());

    it('shows checkbox', () => {
      expect(findCheckbox().exists()).toBe(true);
    });

    it('shows permission name', () => {
      expect(findCheckbox().text()).toBe('Permission A');
    });

    it('shows description icon', () => {
      expect(findDescriptionIcon().props()).toMatchObject({ name: 'information-o' });
    });

    it('shows description popover', () => {
      expect(findPopover().attributes('no-fade')).toBe('');
      expect(findPopover().props()).toMatchObject({
        triggers: 'focus',
        placement: 'auto',
      });
    });

    it('emits a change event when the checkbox is clicked', () => {
      findCheckbox().vm.$emit('change');

      expect(wrapper.emitted('change')).toHaveLength(1);
      expect(wrapper.emitted('change')[0][0]).toBe(permissionWithoutChildren);
    });
  });

  describe('checkbox checked state', () => {
    it.each`
      permission                   | checked
      ${permissionWithoutChildren} | ${false}
      ${permissionWithChildren}    | ${true}
    `('sets checkbox checked state to $checked', ({ permission, checked }) => {
      createComponent({ permission });

      expect(findCheckbox().props('checked')).toBe(checked);
    });
  });

  describe('base role badge', () => {
    it('shows base role badge when base role already grants permission', () => {
      createComponent({ permission: permissionWithChildren });

      expect(findBaseRoleBadge().props('variant')).toBe('info');
      expect(findBaseRoleBadge().text()).toBe('Added from Developer');
    });

    it('does not show base role badge when base role does not grant permission', () => {
      createComponent({ permission: permissionWithoutChildren });

      expect(findBaseRoleBadge().exists()).toBe(false);
    });
  });

  describe('when a role has child permissions', () => {
    beforeEach(() => createComponent({ permission: permissionWithChildren }));

    it('shows child permissions list', () => {
      expect(findChildPermissionsList().exists()).toBe(true);
    });

    it('shows permission checkboxes', () => {
      expect(findChildPermissionCheckboxes()).toHaveLength(2);
    });

    it('emits a change event when a child permission is clicked', () => {
      findChildPermissionCheckboxes().at(0).vm.$emit('change', 'PERMISSION_C');

      expect(wrapper.emitted('change')).toHaveLength(1);
      expect(wrapper.emitted('change')[0][0]).toBe('PERMISSION_C');
    });

    it.each(permissionWithChildren.children)('shows the $value permission', (permission) => {
      const index = permissionWithChildren.children.indexOf(permission);

      expect(findChildPermissionCheckboxes().at(index).props()).toMatchObject({
        permission,
        baseAccessLevel: 'DEVELOPER',
      });
    });
  });

  describe('when a role does not have child permissions', () => {
    it('does not show child permissions list', () => {
      createComponent({ permission: permissionWithoutChildren });

      expect(findChildPermissionsList().exists()).toBe(false);
    });
  });
});
