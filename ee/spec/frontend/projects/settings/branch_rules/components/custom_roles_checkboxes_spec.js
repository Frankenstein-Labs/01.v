import { GlFormCheckbox } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import CustomRolesCheckboxes from 'ee/projects/settings/branch_rules/components/custom_roles_checkboxes.vue';
import { customRolesMock, manyCustomRolesMock } from './mock_data';

describe('CustomRolesCheckboxes', () => {
  let wrapper;

  const formattedRoles = (roles) =>
    roles.map((role) => ({ ...role, id: parseInt(role.id.split('/').pop(), 10) }));

  const createComponent = (props = {}) => {
    wrapper = shallowMountExtended(CustomRolesCheckboxes, {
      propsData: {
        customRoles: formattedRoles(customRolesMock),
        ...props,
      },
    });
  };

  const findSection = () => wrapper.findByTestId('custom-roles-section');
  const findSectionLabel = () => wrapper.findByTestId('custom-roles-section-label');
  const findCheckboxes = () => wrapper.findAllComponents(GlFormCheckbox);
  const findCheckbox = (id) => wrapper.findComponentByTestId(`custom-role-checkbox-${id}`);

  describe('when custom roles are present', () => {
    beforeEach(() => createComponent());

    it('renders the section with the section label', () => {
      expect(findSection().exists()).toBe(true);
      expect(findSectionLabel().text()).toBe('Custom roles');
    });

    it('renders a checkbox per custom role with its name', () => {
      expect(findCheckboxes()).toHaveLength(2);
      expect(findCheckbox(1).text()).toBe('Custom developer');
      expect(findCheckbox(2).text()).toBe('Custom maintainer');
    });

    it('emits change with the id added when a role is checked', () => {
      findCheckbox(1).vm.$emit('change', true);

      expect(wrapper.emitted('change')[0][0]).toEqual([1]);
    });
  });

  describe('when a role is selected', () => {
    beforeEach(() => createComponent({ selectedIds: [2] }));

    it('marks selected roles as checked', () => {
      expect(findCheckbox(1).attributes('checked')).toBeUndefined();
      expect(findCheckbox(2).attributes('checked')).toBe('true');
    });
  });

  describe('when multiple roles are selected', () => {
    beforeEach(() => createComponent({ selectedIds: [1, 2] }));

    it('emits change with the id removed when a selected role is unchecked', () => {
      findCheckbox(1).vm.$emit('change', false);

      expect(wrapper.emitted('change')[0][0]).toEqual([2]);
    });
  });

  describe('when there are no custom roles', () => {
    beforeEach(() => createComponent({ customRoles: [] }));

    it('does not render the section', () => {
      expect(findSection().exists()).toBe(false);
    });
  });

  describe('with a large set of custom roles', () => {
    beforeEach(() => createComponent({ customRoles: formattedRoles(manyCustomRolesMock) }));

    it('renders a checkbox for every role', () => {
      expect(findCheckboxes()).toHaveLength(manyCustomRolesMock.length);
    });
  });
});
