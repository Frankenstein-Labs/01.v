import GroupLinkRoleSelector from 'ee/group_links/group_link_role_selector/components/group_link_role_selector.vue';
import RoleSelector from 'ee/roles_and_permissions/components/role_selector.vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';

describe('GroupLinkRoleSelector', () => {
  let wrapper;

  const createComponent = () => {
    wrapper = shallowMountExtended(GroupLinkRoleSelector, {
      propsData: {
        baseAccessLevelInputName: 'mock_group_link[access_level]',
        memberRoleIdInputName: 'mock_group_link[member_role_id]',
      },
    });
  };

  const findStandardRoleInputElement = () => wrapper.findByTestId('selected-standard-role');
  const findCustomRoleInputElement = () => wrapper.findByTestId('selected-custom-role');
  const findSelectedStandardRole = () => findStandardRoleInputElement().element.value;
  const findSelectedCustomRole = () => findCustomRoleInputElement().element.value;
  const findRoleSelector = () => wrapper.findComponent(RoleSelector);

  describe('component', () => {
    beforeEach(() => {
      createComponent();
    });

    describe('on mount', () => {
      it('sets the correct initial value', () => {
        expect(findSelectedStandardRole()).toBe('');
        expect(findSelectedCustomRole()).toBe('');
      });

      it('sets the correct name attr for input fields', () => {
        expect(findStandardRoleInputElement().attributes('name')).toBe(
          'mock_group_link[access_level]',
        );
        expect(findCustomRoleInputElement().attributes('name')).toBe(
          'mock_group_link[member_role_id]',
        );
      });
    });

    describe('`on-select` event fired', () => {
      it('sets the correct values', async () => {
        const newStandardRoleValue = 20;
        const newCustomRoleValue = 12;

        await findRoleSelector().vm.$emit('on-select', {
          selectedStandardRoleValue: newStandardRoleValue,
          selectedCustomRoleValue: newCustomRoleValue,
        });

        expect(findSelectedStandardRole()).toBe(newStandardRoleValue.toString());
        expect(findSelectedCustomRole()).toBe(newCustomRoleValue.toString());
      });
    });
  });
});
