import { nextTick } from 'vue';
import { GlFormCheckbox } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import AccessLevelsDrawer from '~/projects/settings/branch_rules/components/access_levels_drawer.vue';
import ItemsSelector from '~/projects/settings/branch_rules/components/items_selector.vue';
import {
  allowedToMergeDrawerProps,
  allowedToPushDrawerProps,
} from 'ee_else_ce_jest/projects/settings/branch_rules/components/mock_data';

describe('Edit Access Levels Drawer', () => {
  let wrapper;

  const findCheckboxes = () => wrapper.findAllComponents(GlFormCheckbox);
  const findAdministratorsCheckbox = () => wrapper.findByTestId('admins-role-checkbox');
  const findMaintainersCheckbox = () => wrapper.findByTestId('maintainers-role-checkbox');
  const findDevelopersAndMaintainersCheckbox = () =>
    wrapper.findByTestId('developers-role-checkbox');
  const findNoOneCheckbox = () => wrapper.findByTestId('no-one-role-checkbox');
  const findUsersSelector = () => wrapper.findComponentByTestId('users-selector');
  const findGroupsSelector = () => wrapper.findComponentByTestId('groups-selector');
  const findDeployKeysSelector = () => wrapper.findComponentByTestId('deploy-keys-selector');
  const findSaveButton = () => wrapper.findByText('Save changes');

  const createComponent = (
    props = allowedToMergeDrawerProps,
    showEnterpriseAccessLevels = true,
  ) => {
    wrapper = shallowMountExtended(AccessLevelsDrawer, {
      components: { ItemsSelector },
      propsData: {
        ...props,
      },
      provide: {
        showEnterpriseAccessLevels,
      },
    });
  };

  beforeEach(() => {
    createComponent();
  });

  describe('isOpen watcher', () => {
    beforeEach(() => createComponent({ ...allowedToMergeDrawerProps, roles: [30, 40, 60] }));

    it('renders drawer all checkboxes unchecked by default', () => {
      findCheckboxes().wrappers.forEach((checkbox) =>
        expect(checkbox.attributes('checked')).toBeUndefined(),
      );
    });

    it('updates the checkboxes to the correct state when isOpen is changed', async () => {
      wrapper.setProps({ isOpen: true }); // simulates the drawer being opened from the parent
      await nextTick();

      expect(findAdministratorsCheckbox().attributes('checked')).toBe('true');
      expect(findMaintainersCheckbox().attributes('checked')).toBe('true');
      expect(findDevelopersAndMaintainersCheckbox().attributes('checked')).toBe('true');
      expect(findNoOneCheckbox().attributes('checked')).toBeUndefined();
    });
  });

  it('renders Item Selector with users', () => {
    expect(findUsersSelector().props('items')).toMatchObject([
      {
        __typename: 'UserCore',
        avatarUrl: 'test.com/user.png',
        id: 123,
        name: 'peter',
        src: 'test.com/user.png',
        webUrl: 'test.com',
      },
    ]);
  });

  it('renders Item Selector with groups scoped to the project and without namespace dropdown', () => {
    expect(findGroupsSelector().props('items')).toMatchObject([]);
  });

  describe('for push access levels', () => {
    it('renders Item Selector with deploy keys', () => {
      createComponent({ ...allowedToPushDrawerProps, isPushAccessLevels: true });

      expect(findDeployKeysSelector().props('items')).toMatchObject([
        {
          id: 123123,
          title: 'Deploy key 1',
          user: {
            name: 'User 1',
          },
        },
      ]);
    });
  });

  describe('for merge access levels', () => {
    it('renders Item Selector with deploy keys', () => {
      createComponent({ ...allowedToMergeDrawerProps, isPushAccessLevels: false });

      expect(findDeployKeysSelector().exists()).toBe(false);
    });
  });

  it('enables the save button when users or groups are selected', async () => {
    findUsersSelector().vm.$emit('change', ['some data']);
    await nextTick();
    expect(findSaveButton().attributes('disabled')).toBeUndefined();
  });

  describe('when enterprise access levels are not enabled', () => {
    beforeEach(() => createComponent(allowedToMergeDrawerProps, false));

    it('does not render Item Selector with users', () => {
      expect(findUsersSelector().exists()).toBe(false);
    });

    it('does not render Item Selector with groups', () => {
      expect(findGroupsSelector().exists()).toBe(false);
    });
  });
});
