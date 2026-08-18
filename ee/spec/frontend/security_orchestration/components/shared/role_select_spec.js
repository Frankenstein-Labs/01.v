import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { GlCollapsibleListbox, GlIcon } from '@gitlab/ui';
import { shallowMount } from '@vue/test-utils';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import RoleSelect from 'ee/security_orchestration/components/shared/role_select.vue';
import groupCustomRoles from 'ee/security_orchestration/graphql/queries/group_custom_roles.query.graphql';
import projectCustomRoles from 'ee/security_orchestration/graphql/queries/project_custom_roles.query.graphql';
import { NAMESPACE_TYPES } from 'ee/security_orchestration/constants';

const roleCounts = {
  developer: 3,
  guest: 4,
  maintainer: 2,
  owner: 1,
  reporter: 5,
};

const roleApproverTypes = Object.keys(roleCounts);

describe('RoleSelect component', () => {
  let wrapper;
  const namespacePath = 'path/to/namespace';

  const defaultCustomRole = {
    id: 'gid://gitlab/MemberRole/1',
    name: 'Custom (Gitlab Org - 24)',
    baseAccessLevel: { stringValue: 'REPORTER' },
    enabledPermissions: { edges: [{ node: { value: 'ADMIN_MERGE_REQUEST' } }] },
    __typename: 'MemberRole',
  };

  const multipleDefaultCustomRole = [
    defaultCustomRole,
    {
      id: 'gid://gitlab/MemberRole/2',
      name: 'Custom (Gitlab Org - 25)',
      baseAccessLevel: { stringValue: 'REPORTER' },
      enabledPermissions: { edges: [{ node: { value: 'ADMIN_PROTECTED_BRANCHES' } }] },
      __typename: 'MemberRole',
    },
    {
      id: 'gid://gitlab/MemberRole/3',
      name: 'Custom (Gitlab Org - 26)',
      baseAccessLevel: { stringValue: 'REPORTER' },
      enabledPermissions: {
        edges: [
          { node: { value: 'ADMIN_PROTECTED_BRANCHES' } },
          { node: { value: 'ADMIN_MERGE_REQUEST' } },
        ],
      },
      __typename: 'MemberRole',
    },
  ];

  const createCustomRolesHandlerSuccess = ({ type = 'Project', nodes = [defaultCustomRole] }) =>
    jest.fn().mockResolvedValue({
      data: {
        [type.toLowerCase()]: {
          id: `gid://gitlab/${type}/2`,
          memberRoles: { nodes, __typename: 'MemberRoleConnection' },
          __typename: type,
        },
      },
    });

  const mockProjectCustomRolesHandlerSuccess = createCustomRolesHandlerSuccess({});

  const mockProjectCustomRolesHandlerEmpty = createCustomRolesHandlerSuccess({ nodes: [] });

  const mockGroupCustomRolesHandlerSuccess = createCustomRolesHandlerSuccess({ type: 'Group' });

  const mockProjectMultipleCustomRolesHandlerSuccess = createCustomRolesHandlerSuccess({
    nodes: multipleDefaultCustomRole,
  });

  const createMockApolloProvider = (customHandlers) => {
    Vue.use(VueApollo);

    const defaultHandlers = {
      groupCustomRoles: mockGroupCustomRolesHandlerSuccess,
      projectCustomRoles: mockProjectCustomRolesHandlerSuccess,
    };

    const requestHandlers = { ...defaultHandlers, ...customHandlers };

    return createMockApollo([
      [groupCustomRoles, requestHandlers.groupCustomRoles],
      [projectCustomRoles, requestHandlers.projectCustomRoles],
    ]);
  };

  const createComponent = ({ handlers = {}, propsData = {}, provide = {} } = {}) => {
    wrapper = shallowMount(RoleSelect, {
      apolloProvider: createMockApolloProvider(handlers),
      propsData: {
        selected: [],
        ...propsData,
      },
      provide: {
        roleApproverTypes,
        namespacePath,
        namespaceType: NAMESPACE_TYPES.PROJECT,
        ...provide,
      },
    });
  };

  const findListbox = () => wrapper.findComponent(GlCollapsibleListbox);
  const findIcon = () => wrapper.findComponent(GlIcon);

  describe('default', () => {
    beforeEach(() => {
      createComponent();
    });

    it('emits when a role is selected', async () => {
      const role = 'owner';
      await findListbox().vm.$emit('select', [role]);
      expect(wrapper.emitted('select-items')).toEqual([[{ role_approvers: [role] }]]);
    });

    it('displays the correct listbox validation state', () => {
      expect(findListbox().props('state')).toBe(true);
    });

    it('displays the correct toggle text', () => {
      expect(findListbox().props('toggleText')).toBe('Choose specific role');
    });

    it('does not emit an error', () => {
      expect(wrapper.emitted('error')).toEqual(undefined);
    });

    it('organizes the standard roles into a group', () => {
      expect(findListbox().props('items')).toEqual([
        { text: 'Standard roles', options: expect.any(Array) },
      ]);
    });
  });

  describe('custom props', () => {
    beforeEach(() => {
      createComponent({ propsData: { state: false } });
    });

    it('displays the correct listbox validation state', () => {
      expect(findListbox().props('state')).toBe(false);
    });
  });

  describe('with valid approvers', () => {
    const role = { text: 'Developer', value: 'developer' };

    beforeEach(() => {
      createComponent({ propsData: { selected: [role.value] } });
    });

    it('displays the correct toggle text', () => {
      expect(findListbox().props('toggleText')).toBe(role.text);
    });

    it('emits when a user is deselected', () => {
      findListbox().vm.$emit('select', []);
      expect(wrapper.emitted('select-items')).toEqual([[{ role_approvers: [] }]]);
    });

    it('does not emit an error', () => {
      expect(wrapper.emitted('error')).toEqual(undefined);
    });
  });

  describe('with invalid approvers', () => {
    const validRole = 'developer';
    const invalidRole = 'invalid';

    it('displays the correct toggle text', () => {
      createComponent({ propsData: { selected: [invalidRole] } });
      expect(findListbox().props('toggleText')).toBe('Choose specific role');
    });

    it('emits an error when a user updates to an invalid role', async () => {
      createComponent({ propsData: { selected: [validRole] } });
      await waitForPromises();
      await wrapper.setProps({ selected: [invalidRole] });
      expect(wrapper.emitted('error')).toEqual([[]]);
    });
  });

  describe('custom roles', () => {
    describe('default', () => {
      it('shows the help icon', () => {
        createComponent();
        expect(findIcon().exists()).toBe(true);
      });

      it('retrieves the project custom roles', async () => {
        createComponent();
        await waitForPromises();
        expect(mockProjectCustomRolesHandlerSuccess).toHaveBeenCalled();
        expect(mockGroupCustomRolesHandlerSuccess).not.toHaveBeenCalled();
      });

      it('retrieves the group custom roles', async () => {
        createComponent({
          provide: {
            namespaceType: NAMESPACE_TYPES.GROUP,
          },
        });
        await waitForPromises();
        expect(mockProjectCustomRolesHandlerSuccess).not.toHaveBeenCalled();
        expect(mockGroupCustomRolesHandlerSuccess).toHaveBeenCalled();
      });

      it('adds custom role section to items if custom roles exist', async () => {
        createComponent();
        await waitForPromises();
        expect(findListbox().props('items')).toEqual([
          { text: 'Standard roles', options: expect.any(Array) },
          { text: 'Custom roles', options: expect.any(Array) },
        ]);
      });

      it('does not add custom role section to items if custom roles do not exist', async () => {
        createComponent({
          handlers: { projectCustomRoles: mockProjectCustomRolesHandlerEmpty },
        });
        await waitForPromises();
        expect(findListbox().props('items')).toEqual([
          { text: 'Standard roles', options: expect.any(Array) },
        ]);
      });

      it('only shows custom roles with approver permissions', async () => {
        createComponent({
          handlers: { projectCustomRoles: mockProjectMultipleCustomRolesHandlerSuccess },
        });
        await waitForPromises();
        const customRolesWithApproverPermissions = findListbox()
          .props('items')[1]
          .options.map(({ text }) => text);
        expect(customRolesWithApproverPermissions).toEqual([
          'Custom (Gitlab Org - 24)',
          'Custom (Gitlab Org - 26)',
        ]);
      });
    });

    describe('with valid approvers', () => {
      const customRole = { id: 1, name: 'Custom (Gitlab Org - 24)' };

      it('displays the correct toggle text for a custom role', async () => {
        createComponent({
          propsData: { selected: [customRole.id] },
        });
        await waitForPromises();
        expect(findListbox().props('toggleText')).toBe(customRole.name);
      });

      it('does not emit an invalid role error for custom roles that exist', async () => {
        createComponent();
        await waitForPromises();
        await wrapper.setProps({ selected: [customRole.id] });
        expect(wrapper.emitted('error')).toBeUndefined();
      });

      it('does not emit an invalid role error for custom roles that exist before the custom roles load', async () => {
        createComponent();
        await wrapper.setProps({ selected: [customRole.id] });
        expect(wrapper.emitted('error')).toBeUndefined();
      });
    });

    describe('with invalid approvers', () => {
      const validStandardRole = { text: 'Developer', value: 'developer' };
      const invalidCustomRole = { id: 999, name: 'Non-existent Custom Role' };

      it('displays the correct toggle text', () => {
        createComponent({
          propsData: { selected: [invalidCustomRole, validStandardRole.value] },
        });
        expect(findListbox().props('toggleText')).toBe(validStandardRole.text);
      });

      it('emits an invalid role error for custom roles that do not exist', async () => {
        createComponent();
        await waitForPromises();
        await wrapper.setProps({ selected: [invalidCustomRole.id] });
        expect(wrapper.emitted('error')).toEqual([[]]);
        expect(findListbox().props('toggleText')).toBe('Choose specific role');
      });
    });
  });

  describe('reset roles', () => {
    it('resets all selected roles', async () => {
      createComponent({ propsData: { selected: ['developer'] } });
      await waitForPromises();

      findListbox().vm.$emit('reset');

      expect(wrapper.emitted('select-items')).toEqual([[{ role_approvers: [] }]]);
    });
  });

  describe('css classes', () => {
    it('adds custom css classes to role dropdown', () => {
      createComponent({
        propsData: {
          customDropdownClasses: ['custom-class'],
        },
      });

      expect(findListbox().classes()).toContain('custom-class');
    });
  });
});
