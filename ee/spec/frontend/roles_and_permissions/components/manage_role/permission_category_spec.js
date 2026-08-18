import { GlAnimatedChevronRightDownIcon, GlButton } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import PermissionCategory from 'ee/roles_and_permissions/components/manage_role/permission_category.vue';
import PermissionCheckbox from 'ee/roles_and_permissions/components/manage_role/permission_checkbox.vue';
import { stubComponent } from 'helpers/stub_component';
import { permissionWithoutChildren, permissionWithChildren } from '../../mock_data';

describe('Permission category component', () => {
  let wrapper;

  const category = {
    name: 'Test Category',
    permissions: [permissionWithoutChildren, permissionWithChildren],
  };

  const createComponent = () => {
    wrapper = shallowMountExtended(PermissionCategory, {
      propsData: { category, baseAccessLevel: 'DEVELOPER' },
      stubs: {
        // This stub is needed for Vue 3 tests to pass. Not needed for Vue 2.
        GlAnimatedChevronRightDownIcon: stubComponent(GlAnimatedChevronRightDownIcon, {
          props: ['isOn'],
        }),
      },
    });
  };

  const findHeaderButton = () => wrapper.findComponent(GlButton);
  const findChevronIcon = () => wrapper.findComponent(GlAnimatedChevronRightDownIcon);
  const findAllPermissionCheckboxes = () => wrapper.findAllComponents(PermissionCheckbox);

  describe('on page load', () => {
    beforeEach(() => createComponent());

    it('shows header button', () => {
      expect(findHeaderButton().props('variant')).toBe('link');
    });

    it('shows category name', () => {
      expect(findHeaderButton().text()).toBe('Test Category');
    });

    it('shows chevron icon as open', () => {
      expect(findChevronIcon().props('isOn')).toBe(true);
    });

    describe('permission checkboxes', () => {
      it('shows permission checkboxes', () => {
        expect(findAllPermissionCheckboxes()).toHaveLength(2);
      });

      it.each(category.permissions)('shows $value permission checkbox', (permission) => {
        const index = category.permissions.indexOf(permission);

        expect(findAllPermissionCheckboxes().at(index).props()).toMatchObject({
          permission,
          baseAccessLevel: 'DEVELOPER',
        });
      });
    });

    describe('when header button is clicked', () => {
      beforeEach(() => findHeaderButton().vm.$emit('click'));

      it('shows chevron icon as closed', () => {
        expect(findChevronIcon().props('isOn')).toBe(false);
      });

      it('hides permission checkboxes', () => {
        expect(findAllPermissionCheckboxes()).toHaveLength(0);
      });
    });

    describe('when a permission checkbox is clicked', () => {
      beforeEach(() => findAllPermissionCheckboxes().at(0).vm.$emit('change', 'PERMISSION_A'));

      it('bubbles up the event', () => {
        expect(wrapper.emitted('change')).toHaveLength(1);
        expect(wrapper.emitted('change')[0][0]).toBe('PERMISSION_A');
      });
    });
  });
});
