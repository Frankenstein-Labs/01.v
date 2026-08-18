import { GlAccordion, GlAccordionItem, GlSprintf, GlTruncate } from '@gitlab/ui';
import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import UsersGroupsExceptions from 'ee/security_orchestration/components/policy_drawer/scan_result/policy_exceptions/users_groups_exceptions.vue';
import PolicyExceptionsLoader from 'ee/security_orchestration/components/policy_drawer/scan_result/policy_exceptions/policy_exceptions_loader.vue';
import { NAMESPACE_TYPES } from 'ee/security_orchestration/constants';
import waitForPromises from 'helpers/wait_for_promises';
import createMockApollo from 'helpers/mock_apollo_helper';
import searchProjectMembers from '~/graphql_shared/queries/project_user_members_search.query.graphql';
import searchGroupMembers from '~/graphql_shared/queries/group_users_search.query.graphql';
import getGroups from 'ee/security_orchestration/graphql/queries/get_groups_by_ids.query.graphql';

Vue.use(VueApollo);

describe('UsersGroupsExceptions', () => {
  let wrapper;
  let mockApollo;

  const mockUsers = [{ id: 1 }, { id: 2 }];
  const mockGroups = [{ id: 10 }, { id: 20 }];

  const mockLoadedUsers = [
    {
      id: '1',
      user: {
        id: 'gid://gitlab/User/1',
        name: 'John Doe',
        username: 'johndoe',
        avatarUrl: 'avatarUrl1',
      },
    },
    {
      id: '1',
      user: {
        id: 'gid://gitlab/User/2',
        name: 'Jane Smith',
        username: 'janesmith',
        avatarUrl: 'avatarUrl2',
      },
    },
  ];

  const mockLoadedGroups = [
    {
      id: 'gid://gitlab/Group/10',
      fullName: 'Group One',
      name: 'Group one',
      fullPath: 'fullPath-groupOne',
      avatarUrl: 'avatarUrl1',
    },
    {
      id: 'gid://gitlab/Group/20',
      fullName: 'Group Two',
      name: 'Group two',
      fullPath: 'fullPath-groupTwo',
      avatarUrl: 'avatarUrl2',
    },
  ];

  const searchProjectMembersHandler = jest.fn();
  const searchGroupMembersHandler = jest.fn();
  const getGroupsHandler = jest.fn();

  const createComponent = ({ propsData = {}, provide = {} } = {}) => {
    mockApollo = createMockApollo([
      [searchProjectMembers, searchProjectMembersHandler],
      [searchGroupMembers, searchGroupMembersHandler],
      [getGroups, getGroupsHandler],
    ]);

    wrapper = shallowMountExtended(UsersGroupsExceptions, {
      propsData,
      provide: {
        namespacePath: 'test/project',
        namespaceType: NAMESPACE_TYPES.PROJECT,
        ...provide,
      },
      apolloProvider: mockApollo,
      stubs: {
        GlSprintf,
      },
    });
  };

  const findAccordion = () => wrapper.findComponent(GlAccordion);
  const findAccordionItem = () => wrapper.findComponent(GlAccordionItem);
  const findPolicyExceptionsLoader = () => wrapper.findAllComponents(PolicyExceptionsLoader);
  const findUsersLoader = () => wrapper.findAllComponents(PolicyExceptionsLoader).at(0);
  const findGroupsLoader = () => wrapper.findAllComponents(PolicyExceptionsLoader).at(1);
  const findUserTitle = () => wrapper.findByTestId('user-header');
  const findGroupTitle = () => wrapper.findByTestId('group-header');
  const findUserItems = () => wrapper.findAllByTestId('user-item');
  const findGroupItems = () => wrapper.findAllByTestId('group-item');
  const findFallbackUserIds = () => wrapper.findAllByTestId('user-item-fallback');
  const findFallbackGroupIds = () => wrapper.findAllByTestId('group-item-fallback');

  beforeEach(() => {
    searchProjectMembersHandler.mockClear();
    searchGroupMembersHandler.mockClear();
    getGroupsHandler.mockClear();
  });

  describe('default rendering', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders accordion with correct header level', () => {
      expect(findAccordion().exists()).toBe(true);
      expect(findAccordion().props('headerLevel')).toBe(3);
    });

    it('displays correct title with zero count', () => {
      expect(findAccordionItem().props('title')).toBe('Users and Groups (0)');
    });

    it('does not show any loaders initially', () => {
      expect(findPolicyExceptionsLoader()).toHaveLength(0);
    });

    it('does not show user or group sections when no data', () => {
      expect(findUserTitle().exists()).toBe(false);
      expect(findGroupTitle().exists()).toBe(false);
    });
  });

  describe('with users and groups props', () => {
    beforeEach(() => {
      createComponent({
        propsData: {
          users: mockUsers,
          groups: mockGroups,
        },
      });
    });

    it('displays correct count in title', () => {
      expect(findAccordionItem().props('title')).toBe('Users and Groups (4)');
    });

    it('shows loading state when accordion is opened', async () => {
      await findAccordionItem().vm.$emit('input', true);

      expect(findPolicyExceptionsLoader()).toHaveLength(2);
      expect(findUsersLoader().props('label')).toBe('Loading users');
      expect(findGroupsLoader().props('label')).toBe('Loading groups');
    });
  });

  describe('loading users', () => {
    beforeEach(() => {
      createComponent({
        propsData: {
          users: mockUsers,
        },
      });
    });

    it('shows users loading state', async () => {
      searchProjectMembersHandler.mockResolvedValue({
        data: {
          project: {
            projectMembers: {
              nodes: mockLoadedUsers,
            },
          },
        },
      });

      await findAccordionItem().vm.$emit('input', true);

      expect(findUsersLoader().exists()).toBe(true);
      expect(findUsersLoader().props('label')).toBe('Loading users');
    });

    it('displays loaded users after successful query', async () => {
      searchProjectMembersHandler.mockResolvedValue({
        data: {
          project: {
            id: '1',
            projectMembers: {
              nodes: mockLoadedUsers,
            },
          },
        },
      });

      await findAccordionItem().vm.$emit('input', true);
      await waitForPromises();

      expect(findUserTitle().exists()).toBe(true);
      expect(findUserItems()).toHaveLength(2);
    });

    it('shows fallback user IDs when loading fails', async () => {
      searchProjectMembersHandler.mockRejectedValue(new Error('Network error'));

      await findAccordionItem().vm.$emit('input', true);
      await waitForPromises();

      expect(findUserTitle().exists()).toBe(true);
      expect(findFallbackUserIds()).toHaveLength(2);
      expect(findFallbackUserIds().at(0).text()).toContain('id: 1');
      expect(findFallbackUserIds().at(1).text()).toContain('id: 2');
    });
  });

  describe('loading groups', () => {
    beforeEach(() => {
      createComponent({
        propsData: {
          groups: mockGroups,
        },
      });
    });

    it('shows groups loading state', async () => {
      getGroupsHandler.mockResolvedValue({
        data: {
          groups: {
            nodes: mockLoadedGroups,
          },
        },
      });

      await findAccordionItem().vm.$emit('input', true);

      expect(findGroupsLoader().exists()).toBe(true);
      expect(findGroupsLoader().props('label')).toBe('Loading groups');
    });

    it('displays loaded groups after successful query', async () => {
      getGroupsHandler.mockResolvedValue({
        data: {
          groups: {
            nodes: mockLoadedGroups,
            pageInfo: {},
          },
        },
      });

      await findAccordionItem().vm.$emit('input', true);
      await waitForPromises();

      expect(findGroupTitle().exists()).toBe(true);
      expect(findGroupItems()).toHaveLength(2);
      expect(findGroupItems().at(0).findComponent(GlTruncate).props('text')).toBe('Group One');
      expect(findGroupItems().at(1).findComponent(GlTruncate).props('text')).toBe('Group Two');
    });

    it('shows fallback group IDs when loading fails', async () => {
      getGroupsHandler.mockRejectedValue(new Error('Network error'));

      await findAccordionItem().vm.$emit('input', true);
      await waitForPromises();

      expect(findGroupTitle().exists()).toBe(true);
      expect(findFallbackGroupIds()).toHaveLength(2);
      expect(findFallbackGroupIds().at(0).text()).toContain('id: 10');
      expect(findFallbackGroupIds().at(1).text()).toContain('id: 20');
    });
  });

  describe('namespace type handling', () => {
    it('uses group query for group namespace type', async () => {
      createComponent({
        propsData: {
          users: mockUsers,
        },
        provide: {
          namespaceType: NAMESPACE_TYPES.GROUP,
        },
      });

      searchGroupMembersHandler.mockResolvedValue({
        data: {
          namespace: {
            users: {
              nodes: mockLoadedUsers,
            },
          },
        },
      });

      await findAccordionItem().vm.$emit('input', true);
      await waitForPromises();

      expect(searchGroupMembersHandler).toHaveBeenCalledTimes(1);
      expect(searchGroupMembersHandler).toHaveBeenCalledWith({
        fullPath: 'test/project',
        search: '',
        ids: mockLoadedUsers.map(({ user }) => user.id),
        relations: ['DIRECT', 'DESCENDANTS', 'INHERITED'],
      });
      expect(searchProjectMembersHandler).not.toHaveBeenCalled();
    });
  });

  describe('accordion interaction', () => {
    beforeEach(() => {
      createComponent({
        propsData: {
          users: mockUsers,
          groups: mockGroups,
        },
      });
    });

    it('does not trigger loading when accordion is closed', async () => {
      await findAccordionItem().vm.$emit('input', false);

      expect(searchProjectMembersHandler).not.toHaveBeenCalled();
      expect(getGroupsHandler).not.toHaveBeenCalled();
    });

    it('only loads data once when accordion is opened multiple times', async () => {
      searchProjectMembersHandler.mockResolvedValue({
        data: {
          project: { id: '1', projectMembers: { nodes: mockLoadedUsers, pageInfo: {} } },
        },
      });
      getGroupsHandler.mockResolvedValue({
        data: {
          groups: { nodes: mockLoadedGroups, pageInfo: {} },
        },
      });

      // First open
      await findAccordionItem().vm.$emit('input', true);
      await waitForPromises();

      const firstUserCallCount = searchProjectMembersHandler.mock.calls.length;
      const firstGroupCallCount = getGroupsHandler.mock.calls.length;

      // Second open
      await findAccordionItem().vm.$emit('input', true);
      await waitForPromises();

      expect(searchProjectMembersHandler.mock.calls).toHaveLength(firstUserCallCount);
      expect(getGroupsHandler.mock.calls).toHaveLength(firstGroupCallCount);
    });
  });
});
