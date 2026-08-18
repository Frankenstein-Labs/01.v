import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import { GlCollapsibleListbox } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import waitForPromises from 'helpers/wait_for_promises';
import searchProjectMembers from '~/graphql_shared/queries/project_user_members_search.query.graphql';
import searchGroupMembers from '~/graphql_shared/queries/group_users_search.query.graphql';
import createMockApollo from 'helpers/mock_apollo_helper';
import UserSelect from 'ee/security_orchestration/components/shared/user_select.vue';
import { NAMESPACE_TYPES } from 'ee/security_orchestration/constants';

Vue.use(VueApollo);

const user = {
  id: 'gid://gitlab/User/1',
  name: 'Name 1',
  username: 'name.1',
  avatarUrl: 'https://www.gravatar.com/avatar/1234',
  __typename: 'UserCore',
};

const user2 = {
  id: 'gid://gitlab/User/2',
  name: 'Name 2',
  username: 'name.2',
  avatarUrl: 'https://www.gravatar.com/avatar/1235',
  __typename: 'UserCore',
};

const createProjectMemberResponse = (nodes) => ({
  data: {
    project: {
      id: 'gid://gitlab/Project/6',
      projectMembers: {
        nodes,
        __typename: 'MemberInterfaceConnection',
      },
      __typename: 'Project',
    },
  },
});

const PROJECT_MEMBER_RESPONSE_WITH_DUPLICATE_AND_NULL = createProjectMemberResponse([
  { id: 'gid://gitlab/ProjectMember/1', user, __typename: 'ProjectMember' },
  { id: 'gid://gitlab/ProjectMember/2', user, __typename: 'ProjectMember' },
  { id: 'gid://gitlab/ProjectMember/3', user: user2, __typename: 'ProjectMember' },
  { id: '', user: null, __typename: 'ProjectMember' },
]);

const GROUP_MEMBER_RESPONSE = {
  data: {
    namespace: {
      id: 'gid://gitlab/Group/6',
      users: {
        nodes: [
          {
            id: 'gid://gitlab/GroupMember/1',
            user: { ...user, webUrl: 'path/to/user', webPath: 'path/to/user', status: null },
            __typename: 'GroupMember',
          },
        ],
        pageInfo: {
          hasNextPage: false,
          startCursor: 'start-cursor',
          endCursor: 'end-cursor',
          __typename: 'PageInfo',
        },
        __typename: 'GroupMemberConnection',
      },
      __typename: 'Group',
    },
  },
};

describe('UserSelect component', () => {
  let wrapper;
  const namespacePath = 'path/to/namespace';
  const namespaceType = NAMESPACE_TYPES.PROJECT;
  const projectSearchQueryHandlerSuccess = jest
    .fn()
    .mockResolvedValue(PROJECT_MEMBER_RESPONSE_WITH_DUPLICATE_AND_NULL);
  const groupSearchQueryHandlerSuccess = jest.fn().mockResolvedValue(GROUP_MEMBER_RESPONSE);

  const createComponent = ({ propsData = {}, provide = {}, handlers = {} } = {}) => {
    const fakeApollo = createMockApollo([
      [
        searchProjectMembers,
        handlers.projectSearchQueryHandler || projectSearchQueryHandlerSuccess,
      ],
      [searchGroupMembers, handlers.groupSearchQueryHandler || groupSearchQueryHandlerSuccess],
    ]);

    wrapper = shallowMountExtended(UserSelect, {
      apolloProvider: fakeApollo,
      propsData: {
        selected: [],
        ...propsData,
      },
      provide: {
        namespacePath,
        namespaceType,
        ...provide,
      },
      stubs: {
        GlCollapsibleListbox,
      },
    });
  };

  const findListbox = () => wrapper.findComponent(GlCollapsibleListbox);

  const waitForApolloAndVue = async () => {
    await nextTick();
    jest.runOnlyPendingTimers();
    await waitForPromises();
  };

  describe('default', () => {
    beforeEach(async () => {
      createComponent();
      await waitForApolloAndVue();
    });

    it('displays the correct listbox validation state', () => {
      expect(findListbox().props('state')).toBe(true);
    });

    it('removes duplicates and nulls from user request', () => {
      expect(findListbox().props('items')).toEqual([
        { ...user, id: user.id, text: user.name, username: `@${user.username}`, value: user.id },
        {
          ...user2,
          id: user2.id,
          text: user2.name,
          username: `@${user2.username}`,
          value: user2.id,
        },
      ]);
    });

    it('filters users when search is performed in listbox', async () => {
      expect(projectSearchQueryHandlerSuccess).toHaveBeenCalledWith({
        fullPath: namespacePath,
        search: '',
      });

      const initialItems = findListbox().props('items');
      expect(initialItems).toHaveLength(2);

      const searchTerm = 'Name 1';
      findListbox().vm.$emit('search', searchTerm);
      await waitForApolloAndVue();

      expect(projectSearchQueryHandlerSuccess).toHaveBeenCalledWith({
        fullPath: namespacePath,
        search: searchTerm,
      });

      const filteredItems = findListbox().props('items');
      expect(filteredItems.every((item) => item.text.includes('Name'))).toBe(true);
    });

    it('emits when a user is selected', async () => {
      createComponent({ propsData: { selected: [user.id] } });
      await waitForApolloAndVue();
      await waitForPromises();

      expect(findListbox().props('toggleText')).toBe('Name 1');

      findListbox().vm.$emit('select', [user.id]);
      await nextTick();

      expect(wrapper.emitted('select-items')).toEqual([[{ user_approvers_ids: [1] }]]);
    });

    it('emits when a user is deselected', async () => {
      createComponent({ propsData: { selected: [user.id] } });
      await waitForApolloAndVue();
      await waitForPromises();

      findListbox().vm.$emit('select', []);
      await nextTick();

      expect(wrapper.emitted('select-items')[0]).toEqual([{ user_approvers_ids: [] }]);
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

  it('requests project members at the project-level', async () => {
    createComponent();
    await waitForApolloAndVue();

    expect(projectSearchQueryHandlerSuccess).toHaveBeenCalledWith({
      fullPath: namespacePath,
      search: '',
    });

    const items = findListbox().props('items');
    expect(items).toHaveLength(2);
    expect(items[0].text).toBe('Name 1');
  });

  it('requests group members at the group-level', async () => {
    createComponent({ provide: { namespaceType: NAMESPACE_TYPES.GROUP } });
    await waitForApolloAndVue();

    expect(groupSearchQueryHandlerSuccess).toHaveBeenCalledWith({
      fullPath: namespacePath,
      search: '',
      relations: ['DIRECT', 'DESCENDANTS', 'INHERITED'],
    });

    const items = findListbox().props('items');
    expect(items).toHaveLength(1);
    expect(items[0].text).toBe('Name 1');
  });

  it('sets correct toggle text when only approver id is provided', async () => {
    createComponent({ propsData: { selected: [1, 2] } });
    await waitForApolloAndVue();
    await waitForPromises();

    expect(findListbox().props('toggleText')).toBe('Name 1, Name 2');
  });

  describe('preserving selection', () => {
    it('preserves initial selection after search', async () => {
      createComponent({
        propsData: {
          selected: [user.id],
        },
      });

      await waitForApolloAndVue();

      expect(findListbox().props('items')).toHaveLength(2);
      expect(findListbox().props('toggleText')).toBe(user.name);

      await findListbox().vm.$emit('search', user2.name);

      expect(findListbox().props('items')).toHaveLength(1);
      expect(findListbox().props('selected')).toEqual([user.id]);

      await wrapper.findComponentByTestId(`listbox-item-${user2.id}`).vm.$emit('select', true);

      expect(wrapper.emitted('select-items')).toEqual([[{ user_approvers_ids: [1, 2] }]]);
    });
  });

  describe('disabled state', () => {
    it('renders disabled state', () => {
      createComponent({
        propsData: {
          disabled: true,
        },
      });

      expect(findListbox().props('disabled')).toBe(true);
    });
  });

  describe('reset selected users', () => {
    it('reset selected users when there are no selected users', async () => {
      createComponent({ propsData: { selected: [1, 2], resetOnEmpty: true } });
      await waitForApolloAndVue();
      await waitForPromises();

      expect(findListbox().props('selected')).toEqual([
        'gid://gitlab/User/1',
        'gid://gitlab/User/2',
      ]);

      await wrapper.setProps({ selected: [] });

      expect(findListbox().props('selected')).toEqual([]);
    });

    it('update selected users when new users selected', async () => {
      createComponent({ propsData: { selected: [1], resetOnEmpty: true } });
      await waitForApolloAndVue();
      await waitForPromises();

      expect(findListbox().props('selected')).toEqual(['gid://gitlab/User/1']);

      await wrapper.setProps({ selected: [1, 2] });

      expect(findListbox().props('selected')).toEqual([
        'gid://gitlab/User/1',
        'gid://gitlab/User/2',
      ]);
    });
  });

  describe('render selected names', () => {
    it.each(['@name.1', 'name.1'])('renders users selected by name or username', async (value) => {
      createComponent({ propsData: { selectedNames: [value] } });
      await waitForApolloAndVue();
      await waitForPromises();

      expect(findListbox().props('selected')).toEqual(['gid://gitlab/User/1']);
      expect(wrapper.emitted('select-items')).toEqual([[{ user_approvers_ids: [1] }]]);
    });
  });

  describe('render selected names and ids', () => {
    it('renders both selected names and ids', async () => {
      createComponent({
        propsData: {
          selectedNames: ['name.2'],
          selected: [1],
        },
      });

      await waitForApolloAndVue();
      await waitForPromises();

      expect(findListbox().props('selected')).toEqual([
        'gid://gitlab/User/2',
        'gid://gitlab/User/1',
      ]);
      expect(wrapper.emitted('select-items')).toEqual([
        [{ user_approvers_ids: [1] }],
        [{ user_approvers_ids: [2, 1] }],
      ]);
    });
  });

  describe('reset users', () => {
    it('resets all selected users', async () => {
      createComponent({ propsData: { selectedNames: ['name.1'] } });
      await waitForApolloAndVue();
      await waitForPromises();

      findListbox().vm.$emit('reset');
      expect(wrapper.emitted('select-items')).toEqual([
        [{ user_approvers_ids: [1] }],
        [{ user_approvers_ids: [] }],
      ]);
    });
  });

  describe('error handling', () => {
    it('emits error when query fails', async () => {
      createComponent({ handlers: { projectSearchQueryHandler: jest.fn().mockRejectedValue({}) } });
      await waitForApolloAndVue();
      await waitForPromises();

      expect(wrapper.emitted('error')).toHaveLength(1);
    });
  });

  describe('selected user ids from yaml that were not initially loaded', () => {
    it('loads selected users if not initially loaded', async () => {
      createComponent({ propsData: { selected: [4, 5] } });
      await waitForApolloAndVue();
      await waitForPromises();

      expect(projectSearchQueryHandlerSuccess).toHaveBeenCalledTimes(2);

      expect(projectSearchQueryHandlerSuccess).toHaveBeenNthCalledWith(1, {
        fullPath: namespacePath,
        search: '',
      });

      expect(projectSearchQueryHandlerSuccess).toHaveBeenNthCalledWith(2, {
        fullPath: namespacePath,
        search: '',
        ids: ['gid://gitlab/User/4', 'gid://gitlab/User/5'],
      });
    });
  });
});
