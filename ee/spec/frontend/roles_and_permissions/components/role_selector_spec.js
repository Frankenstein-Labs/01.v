import { GlCollapsibleListbox } from '@gitlab/ui';
import RoleSelector from 'ee/roles_and_permissions/components/role_selector.vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';

const flatten = [
  { accessLevel: 10, memberRoleId: null, text: 'Guest', value: 'role-static-1' },
  { accessLevel: 30, memberRoleId: null, text: 'Developer', value: 'role-static-2' },
  { accessLevel: 30, memberRoleId: 10, text: 'Custom Role', value: 'role-custom-3' },
];
const formatted = [
  {
    text: 'Standard roles',
    options: [
      { accessLevel: 10, memberRoleId: null, text: 'Guest', value: 'role-static-1' },
      { accessLevel: 30, memberRoleId: null, text: 'Developer', value: 'role-static-2' },
    ],
  },
  {
    text: 'Custom roles based on Developer',
    options: [{ accessLevel: 30, memberRoleId: 10, text: 'Custom Role', value: 'role-custom-3' }],
  },
];

jest.mock('ee/members/utils', () => ({
  ...jest.requireActual('ee/members/utils'),
  roleDropdownItems: jest.fn().mockReturnValue({ flatten, formatted }),
}));

describe('RoleSelector', () => {
  let wrapper;

  const defaultProvidedData = {
    standardRoles: {},
    currentStandardRole: 30,
    currentCustomRoleId: 10,
  };

  const createComponent = (providedData = {}) => {
    wrapper = shallowMountExtended(RoleSelector, {
      provide: {
        ...defaultProvidedData,
        ...providedData,
      },
    });
  };

  const findListBox = () => wrapper.findComponent(GlCollapsibleListbox);
  const findSelectedProp = () => findListBox().props('selected');
  const findItemsProp = () => findListBox().props('items');
  const findSelected = () => flatten.find((item) => item.value === findSelectedProp()).text;
  const selectListboxItem = (value) => findListBox().vm.$emit('select', value);

  describe('dropdown', () => {
    describe('on creation', () => {
      beforeEach(() => {
        createComponent({ currentStandardRole: null, currentCustomRoleId: null });
      });

      it('sets toggle-text as the placeholder', () => {
        expect(findListBox().props('toggleText')).toBe('Select a role');
      });
    });

    describe('when a custom role is set', () => {
      beforeEach(() => {
        createComponent();
      });

      it('shows the categories', () => {
        expect(findItemsProp()).toBe(formatted);
      });

      it('sets the correct initial value', () => {
        expect(findSelected()).toBe('Custom Role');
      });

      it('sets toggle-text as the custom role name', () => {
        expect(findListBox().props('toggleText')).toBe('Custom Role');
      });
    });

    describe('when a custom role is not set', () => {
      beforeEach(() => {
        createComponent({ currentCustomRoleId: null });
      });

      it('sets the correct initial value', () => {
        expect(findSelected()).toBe('Developer');
      });

      it('sets toggle-text as the role name', () => {
        expect(findListBox().props('toggleText')).toBe('Developer');
      });
    });

    describe('selecting items', () => {
      beforeEach(() => {
        createComponent();
      });

      it('emits an event with the correct values when selecting a dropdown item', async () => {
        for await (const [index, { accessLevel, memberRoleId, value }] of flatten.entries()) {
          await selectListboxItem(value);

          expect(wrapper.emitted('on-select')[index]).toEqual([
            { selectedStandardRoleValue: accessLevel, selectedCustomRoleValue: memberRoleId },
          ]);
        }
      });
    });
  });
});
