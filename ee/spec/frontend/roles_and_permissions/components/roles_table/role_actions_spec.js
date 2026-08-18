import { GlDisclosureDropdown, GlIcon, GlPopover, GlButton } from '@gitlab/ui';
import { nextTick } from 'vue';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import RoleActions from 'ee/roles_and_permissions/components/roles_table/role_actions.vue';
import DeleteRoleTooltipWrapper from 'ee/roles_and_permissions/components/delete_role_tooltip_wrapper.vue';
import {
  standardRoles,
  mockMemberRole,
  adminRoles,
  mockMemberRoleWithUsers,
  mockMemberRoleWithSecurityPolicies,
  mockAdminRoleWithLdapLinks,
} from '../../mock_data';

describe('Role actions', () => {
  let wrapper;

  const mockToastShow = jest.fn();

  const createComponent = ({ role = mockMemberRole } = {}) => {
    wrapper = mountExtended(RoleActions, {
      propsData: { role },
      mocks: { $toast: { show: mockToastShow } },
    });
  };

  const findDropdown = () => wrapper.findComponent(GlDisclosureDropdown);
  const findRoleIdItem = () => wrapper.findComponentByTestId('role-id-item');
  const findViewDetailsItem = () => wrapper.findComponentByTestId('view-details-item');
  const findEditRoleItem = () => wrapper.findComponentByTestId('edit-role-item');
  const findDeleteRoleItem = () => wrapper.findComponentByTestId('delete-role-item');
  const findDeleteRoleTooltipWrapper = () => wrapper.findComponent(DeleteRoleTooltipWrapper);
  const findPopover = () => wrapper.findComponent(GlPopover);

  const clickDropdownButton = () => {
    return findDropdown().findComponent(GlButton).trigger('click');
  };

  describe('common behavior', () => {
    beforeEach(() => createComponent());

    it('renders the actions dropdown', () => {
      expect(findDropdown().props()).toMatchObject({
        icon: 'ellipsis_v',
        category: 'tertiary',
        noCaret: true,
      });
    });

    it('shows View details item', () => {
      expect(findViewDetailsItem().props('item')).toMatchObject({
        text: 'View details',
        href: 'role/path/1',
      });
    });

    it('does not render the popover', () => {
      expect(findPopover().exists()).toBe(false);
    });
  });

  describe.each`
    type         | role                | id      | expectedText          | expectedToast
    ${'default'} | ${standardRoles[0]} | ${'10'} | ${'Access level: 10'} | ${'Access level copied to clipboard'}
    ${'custom'}  | ${mockMemberRole}   | ${'1'}  | ${'Role ID: 1'}       | ${'Role ID copied to clipboard'}
    ${'admin'}   | ${adminRoles[0]}    | ${'3'}  | ${'Role ID: 3'}       | ${'Role ID copied to clipboard'}
  `('role ID item for $type role', ({ role, id, expectedText, expectedToast }) => {
    beforeEach(() => createComponent({ role }));

    it('shows clipboard icon', () => {
      expect(findRoleIdItem().findComponent(GlIcon).props('name')).toBe('copy-to-clipboard');
    });

    it('shows role ID', () => {
      expect(findRoleIdItem().attributes('data-clipboard-text')).toBe(id);
      expect(findRoleIdItem().text()).toBe(expectedText);
    });

    it('shows copied to clipboard toast when clicked', async () => {
      findRoleIdItem().vm.$emit('action');
      await nextTick();

      expect(mockToastShow).toHaveBeenCalledWith(expectedToast);
    });
  });

  describe('for default role', () => {
    beforeEach(() => createComponent({ role: standardRoles[0] }));

    it('does not show Edit role item', () => {
      expect(findEditRoleItem().exists()).toBe(false);
    });

    it('does not show Delete role item', () => {
      expect(findDeleteRoleItem().exists()).toBe(false);
    });
  });

  describe('for custom role', () => {
    beforeEach(() => {
      createComponent();
      return clickDropdownButton();
    });

    it('shows Edit role item', () => {
      expect(findEditRoleItem().props('item')).toMatchObject({
        text: 'Edit role',
        href: 'role/path/1/edit',
      });
    });

    describe('delete role item', () => {
      it('shows delete tooltip wrapper', () => {
        expect(findDeleteRoleTooltipWrapper().props()).toMatchObject({
          role: mockMemberRole,
          containerId: 'dropdown-1',
        });
      });

      it('shows item', () => {
        expect(findDeleteRoleItem().props('item')).toMatchObject({
          text: 'Delete role',
          variant: 'danger',
          extraAttrs: { disabled: false },
        });
      });

      it('emits delete event when clicked', async () => {
        findDeleteRoleItem().vm.$emit('action');
        await nextTick();

        expect(wrapper.emitted('delete')).toHaveLength(1);
      });

      it.each`
        role                                  | description
        ${mockMemberRoleWithUsers}            | ${'users'}
        ${mockMemberRoleWithSecurityPolicies} | ${'dependent security policies'}
        ${mockAdminRoleWithLdapLinks}         | ${'dependent admin role ldap syncs'}
      `('disables delete item when role has $description', async ({ role }) => {
        await wrapper.setProps({ role });

        expect(findDeleteRoleItem().props('item')).toMatchObject({
          variant: null,
          extraAttrs: { disabled: true },
        });
      });
    });
  });
});
