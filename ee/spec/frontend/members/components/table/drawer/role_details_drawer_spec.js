import { GlIcon, GlSprintf } from '@gitlab/ui';
import { nextTick } from 'vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import RoleDetailsDrawer from '~/members/components/table/drawer/role_details_drawer.vue';
import { stubComponent } from 'helpers/stub_component';
import MembersTableCell from 'ee/members/components/table/members_table_cell.vue';
import RoleBadges from 'ee/members/components/table/role_badges.vue';
import { roleDropdownItems } from 'ee/members/utils';
import { getSlotFunction } from '~/lib/utils/vue3compat/normalize_render';
import waitForPromises from 'helpers/wait_for_promises';
import {
  member as baseRoleMember,
  updateableCustomRoleMember,
  updateableMember,
} from '../../../mock_data';

describe('Role details drawer', () => {
  const { permissions } = updateableCustomRoleMember.customRoles[1];
  const dropdownItems = roleDropdownItems(updateableCustomRoleMember);
  const currentRole = dropdownItems.flatten.find(
    (role) => role.memberRoleId === updateableCustomRoleMember.accessLevel.memberRoleId,
  );
  let wrapper;

  const createWrapper = ({ member = updateableCustomRoleMember } = {}) => {
    wrapper = shallowMountExtended(RoleDetailsDrawer, {
      propsData: { member },
      stubs: {
        GlSprintf,
        RoleBadges,
        MembersTableCell: stubComponent(MembersTableCell, {
          // Vue 3-style zero-arg render; opt out of @vue/compat's legacy
          // render-function emulation, which misclassifies it.
          compatConfig: { RENDER_FUNCTION: false },
          render() {
            return getSlotFunction(this)({
              memberType: 'user',
              isCurrentUser: false,
              permissions: { canUpdate: member.canUpdate },
            });
          },
        }),
      },
    });
  };

  const findRoleText = () => wrapper.findByTestId('role-text');
  const findBaseRole = () => wrapper.findByTestId('base-role');
  const findPermissions = () => wrapper.findAllByTestId('permission');
  const findPermissionAt = (index) => findPermissions().at(index);
  const findPermissionNameAt = (index) => wrapper.findAllByTestId('permission-name').at(index);
  const findPermissionDescriptionAt = (index) =>
    wrapper.findAllByTestId('permission-description').at(index);

  it('shows role badges', async () => {
    createWrapper();
    await waitForPromises();

    expect(wrapper.findComponent(RoleBadges).props()).toEqual({
      member: updateableCustomRoleMember,
      role: currentRole,
    });
  });

  describe('when the member has a base role', () => {
    beforeEach(() => createWrapper({ member: baseRoleMember }));

    it('does not show the base role in the permissions section', () => {
      expect(findBaseRole().exists()).toBe(false);
    });

    it('does not show any permissions', () => {
      expect(findPermissions()).toHaveLength(0);
    });
  });

  describe('when the member has a custom role', () => {
    beforeEach(createWrapper);

    it('shows "No description" when there is no role description', async () => {
      // Create a member that's assigned to a non-existent custom role.
      const member = { ...updateableMember, accessLevel: { memberRoleId: 999 } };
      wrapper.setProps({ member });
      await nextTick();
      const noDescriptionSpan = wrapper.findByTestId('description-value').find('span');

      expect(noDescriptionSpan.text()).toBe('No description');
      expect(noDescriptionSpan.classes('gl-text-subtle')).toBe(true);
    });

    it('shows the base role in the permissions section', () => {
      expect(findBaseRole().text()).toMatchInterpolatedText('Base role: Guest');
    });

    it('shows the expected number of permissions', () => {
      expect(findPermissions()).toHaveLength(2);
    });

    describe.each(permissions)(`for permission '$name'`, (permission) => {
      const index = permissions.indexOf(permission);

      it('shows the check icon', () => {
        expect(findPermissionAt(index).findComponent(GlIcon).props('name')).toBe('check');
      });

      it('shows the permission name', () => {
        expect(findPermissionNameAt(index).text()).toBe(`Permission ${index}`);
      });

      it('shows the permission description', () => {
        expect(findPermissionDescriptionAt(index).text()).toBe(`Permission description ${index}`);
      });
    });
  });

  // Minimal Access and logged out users can't see custom roles data, but should still see the custom role name.
  describe('when the user does not have access to custom roles data', () => {
    it('shows the custom role name', () => {
      const member = { ...updateableCustomRoleMember, customRoles: [], canUpdate: false };
      createWrapper({ member });

      expect(findRoleText().text()).toBe('custom role 1');
    });
  });
});
