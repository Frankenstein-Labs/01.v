import { GlCollapsibleListbox } from '@gitlab/ui';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import { roleDropdownItems } from 'ee/members/utils';
import RoleSelector from '~/members/components/role_selector.vue';
import { visitUrl } from '~/lib/utils/url_utility';
import { upgradedMember } from '../mock_data';

jest.mock('~/lib/utils/url_utility');

describe('Role selector', () => {
  const dropdownItems = roleDropdownItems(upgradedMember);
  let wrapper;

  const createWrapper = ({
    roles = dropdownItems,
    value = dropdownItems.flatten[0],
    loading,
  } = {}) => {
    wrapper = mountExtended(RoleSelector, {
      propsData: { roles, value, loading },
      provide: { manageMemberRolesPath: 'path' },
    });
  };

  const findDropdown = () => wrapper.findComponent(GlCollapsibleListbox);
  const getDropdownItem = (id) => wrapper.findByTestId(`listbox-item-${id}`);
  const findRoleDescription = (id) => getDropdownItem(id).find('[data-testid="role-description"]');

  beforeEach(() => {
    createWrapper();
  });

  describe('role description', () => {
    it.each(dropdownItems.formatted[0].options)(
      'shows the dropdown description for base role $text',
      ({ value, dropdownDescription }) => {
        const description = findRoleDescription(value);

        expect(description.exists()).toBe(true);
        expect(description.text()).toBe(dropdownDescription);
        expect(description.find('span').classes('gl-text-subtle')).toBe(true);
      },
    );

    it('shows the role description for custom role', () => {
      const description = findRoleDescription('role-custom-101');

      expect(description.text()).toBe('custom role 1 description');
      expect(description.find('span').classes('gl-text-subtle')).toBe(true);
    });

    it('does not show description when custom role has no description', () => {
      expect(findRoleDescription('role-custom-102').exists()).toBe(false);
    });
  });

  describe('manage roles link', () => {
    it('shows manage role link when there is a manageMemberRolesPath', () => {
      expect(findDropdown().props('resetButtonLabel')).toBe('Manage roles');
    });

    it('opens manageMemberRolesPath in a new tab when the link is clicked', () => {
      findDropdown().vm.$emit('reset');

      expect(visitUrl).toHaveBeenCalledTimes(1);
      expect(visitUrl).toHaveBeenCalledWith('path');
    });
  });
});
