import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { createAlert } from '~/alert';
import getProjectMemberRoles from 'ee/graphql_shared/queries/project_member_roles.query.graphql';
import AccessLevelsDrawerEE from 'ee/projects/settings/branch_rules/components/access_levels_drawer.vue';
import AccessLevelsDrawerCe from '~/projects/settings/branch_rules/components/access_levels_drawer.vue';
import CustomRolesCheckboxes from 'ee/projects/settings/branch_rules/components/custom_roles_checkboxes.vue';
import {
  allowedToMergeDrawerProps,
  projectMemberRolesResponse,
  customRolesMock,
} from './mock_data';

jest.mock('~/alert');

Vue.use(VueApollo);

describe('EE Edit Access Levels Drawer', () => {
  let wrapper;
  let memberRolesHandler;

  const findCustomRolesCheckboxes = () => wrapper.findComponent(CustomRolesCheckboxes);

  const createComponent = ({
    props = {},
    showEnterpriseAccessLevels = true,
    customRolesForProtectedBranchesEnabled = true,
    memberRoles,
    queryError = false,
  } = {}) => {
    memberRolesHandler = queryError
      ? jest.fn().mockRejectedValue(new Error('GraphQL error'))
      : jest
          .fn()
          .mockResolvedValue(
            memberRoles ? projectMemberRolesResponse(memberRoles) : projectMemberRolesResponse(),
          );

    wrapper = shallowMountExtended(AccessLevelsDrawerEE, {
      apolloProvider: createMockApollo([[getProjectMemberRoles, memberRolesHandler]]),
      stubs: {
        AccessLevelsDrawerCe,
      },
      propsData: {
        ...allowedToMergeDrawerProps,
        projectPath: 'group/project',
        ...props,
      },
      provide: {
        showEnterpriseAccessLevels,
        customRolesForProtectedBranchesEnabled,
      },
    });
  };

  describe('fetching custom roles', () => {
    it('does not fetch custom roles when the drawer is closed on mount', () => {
      createComponent();

      expect(memberRolesHandler).not.toHaveBeenCalled();
    });

    it('fetches custom roles when mounted with the drawer already open', async () => {
      createComponent({ props: { isOpen: true } });
      await waitForPromises();

      expect(memberRolesHandler).toHaveBeenCalledWith({ fullPath: 'group/project' });
    });

    it('fetches custom roles when the drawer is opened', async () => {
      createComponent();
      wrapper.setProps({ isOpen: true });
      await waitForPromises();

      expect(memberRolesHandler).toHaveBeenCalledWith({ fullPath: 'group/project' });
    });

    it('does not refetch custom roles when the drawer is reopened', async () => {
      createComponent();
      wrapper.setProps({ isOpen: true });
      await waitForPromises();

      wrapper.setProps({ isOpen: false });
      await waitForPromises();
      wrapper.setProps({ isOpen: true });
      await waitForPromises();

      expect(memberRolesHandler).toHaveBeenCalledTimes(1);
    });

    it('does not fetch custom roles without enterprise access levels', async () => {
      createComponent({ showEnterpriseAccessLevels: false });
      wrapper.setProps({ isOpen: true });
      await waitForPromises();

      expect(memberRolesHandler).not.toHaveBeenCalled();
    });

    it('does not fetch custom roles when the feature flag is disabled', async () => {
      createComponent({ customRolesForProtectedBranchesEnabled: false });
      wrapper.setProps({ isOpen: true });
      await waitForPromises();

      expect(memberRolesHandler).not.toHaveBeenCalled();
    });
  });

  describe('custom roles section', () => {
    it('renders the custom roles with the fetched roles when present', async () => {
      createComponent();
      wrapper.setProps({ isOpen: true });
      await waitForPromises();

      expect(findCustomRolesCheckboxes().props('customRoles')).toEqual([
        expect.objectContaining({ id: 1, name: 'Custom developer' }),
        expect.objectContaining({ id: 2, name: 'Custom maintainer' }),
      ]);
    });

    it('forwards memberRoles prop to the CE drawer for preselection', async () => {
      const savedMemberRoles = customRolesMock.map(({ id, name }) => ({ id, name }));
      createComponent({ props: { memberRoles: savedMemberRoles } });
      wrapper.setProps({ isOpen: true });
      await waitForPromises();

      expect(wrapper.findComponent(AccessLevelsDrawerCe).props('memberRoles')).toEqual(
        savedMemberRoles,
      );
    });

    it('passes an empty list when there are no custom roles', async () => {
      createComponent({ memberRoles: [] });
      wrapper.setProps({ isOpen: true });
      await waitForPromises();

      expect(findCustomRolesCheckboxes().props('customRoles')).toEqual([]);
    });

    it('forwards selection changes through the slot onChange handler', async () => {
      createComponent();
      wrapper.setProps({ isOpen: true });
      await waitForPromises();

      findCustomRolesCheckboxes().vm.$emit('change', [1]);
      await nextTick();

      expect(findCustomRolesCheckboxes().props('selectedIds')).toEqual([1]);
    });

    it('does not render the custom roles section when the feature flag is disabled', async () => {
      createComponent({ customRolesForProtectedBranchesEnabled: false });
      wrapper.setProps({ isOpen: true });
      await waitForPromises();

      expect(findCustomRolesCheckboxes().exists()).toBe(false);
    });

    it('creates an alert and does not render any roles when fetching fails', async () => {
      createComponent({ queryError: true });
      wrapper.setProps({ isOpen: true });
      await waitForPromises();

      expect(createAlert).toHaveBeenCalledWith(
        expect.objectContaining({
          message: 'Something went wrong while fetching custom roles.',
        }),
      );
      expect(findCustomRolesCheckboxes().props('customRoles')).toEqual([]);
    });
  });
});
