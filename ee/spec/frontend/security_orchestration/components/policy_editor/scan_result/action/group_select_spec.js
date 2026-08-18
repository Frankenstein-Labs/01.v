import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import { GlCollapsibleListbox } from '@gitlab/ui';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import waitForPromises from 'helpers/wait_for_promises';
import searchDescendantGroups from 'ee/security_orchestration/graphql/queries/get_descendant_groups.query.graphql';
import searchNamespaceGroups from 'ee/security_orchestration/graphql/queries/get_namespace_groups.query.graphql';
import createMockApollo from 'helpers/mock_apollo_helper';
import GroupSelect from 'ee/security_orchestration/components/policy_editor/scan_result/action/group_select.vue';

Vue.use(VueApollo);

const rootGroup = {
  avatarUrl: null,
  id: 'gid://gitlab/Group/1',
  fullName: 'Name 1',
  fullPath: 'path/to/name-1',
};

const group = {
  avatarUrl: null,
  id: 'gid://gitlab/Group/2',
  fullName: 'Name 2',
  fullPath: 'path/to/name-2',
  __typename: 'Group',
};

const group2 = {
  avatarUrl: null,
  id: 'gid://gitlab/Group/3',
  fullName: 'Name 3',
  fullPath: 'path/to/name-3',
  __typename: 'Group',
};

const DESCENDANT_GROUP_RESPONSE = {
  data: {
    group: {
      ...rootGroup,
      descendantGroups: {
        nodes: [
          {
            ...group,
          },
          {
            ...group2,
          },
          null,
        ],
        pageInfo: {
          hasNextPage: false,
          hasPreviousPage: false,
          startCursor: null,
          endCursor: null,
          __typename: 'PageInfo',
        },
        __typename: 'GroupConnection',
      },
      __typename: 'Group',
    },
  },
};

const NAMESPACE_GROUP_RESPONSE = {
  data: {
    groups: {
      nodes: [
        {
          ...group,
        },
        {
          ...group2,
        },
        null,
      ],
      __typename: 'GroupConnection',
    },
  },
};

describe('GroupSelect component', () => {
  let wrapper;
  const rootNamespacePath = 'root/path/to/namespace';
  const searchDescendantGroupsQueryHandlerSuccess = jest
    .fn()
    .mockResolvedValue(DESCENDANT_GROUP_RESPONSE);
  const searchNamespaceGroupsQueryHandlerSuccess = jest
    .fn()
    .mockResolvedValue(NAMESPACE_GROUP_RESPONSE);

  const createComponent = ({ propsData = {}, provide = {}, handlers = {} } = {}) => {
    const fakeApollo = createMockApollo([
      [
        searchDescendantGroups,
        handlers.searchDescendantGroupsQueryHandler || searchDescendantGroupsQueryHandlerSuccess,
      ],
      [
        searchNamespaceGroups,
        handlers.searchNamespaceGroupsQueryHandler || searchNamespaceGroupsQueryHandlerSuccess,
      ],
    ]);

    wrapper = mountExtended(GroupSelect, {
      apolloProvider: fakeApollo,
      propsData: {
        existingApprovers: [],
        ...propsData,
      },
      provide: {
        globalGroupApproversEnabled: true,
        rootNamespacePath,
        ...provide,
      },
    });
  };

  const findListbox = () => wrapper.findComponent(GlCollapsibleListbox);

  const waitForApolloAndVue = async () => {
    await nextTick();
    jest.runOnlyPendingTimers();
  };

  describe('default', () => {
    beforeEach(async () => {
      createComponent();
      await waitForApolloAndVue();
    });

    it('displays the correct listbox validation state', () => {
      expect(findListbox().props('state')).toBe(true);
    });

    it('filters groups when search is performed in listbox', async () => {
      expect(searchNamespaceGroupsQueryHandlerSuccess).toHaveBeenCalledTimes(1);
      expect(searchNamespaceGroupsQueryHandlerSuccess).toHaveBeenCalledWith({
        rootNamespacePath,
        search: '',
      });
      expect(searchDescendantGroupsQueryHandlerSuccess).not.toHaveBeenCalled();

      const initialItems = findListbox().props('items');
      expect(initialItems).toHaveLength(2);

      const searchTerm = 'test';
      findListbox().vm.$emit('search', searchTerm);
      await waitForApolloAndVue();

      expect(searchNamespaceGroupsQueryHandlerSuccess).toHaveBeenCalledTimes(2);
      expect(searchNamespaceGroupsQueryHandlerSuccess).toHaveBeenNthCalledWith(2, {
        rootNamespacePath,
        search: searchTerm,
      });
    });

    it('emits when a group is selected', async () => {
      findListbox().vm.$emit('select', [group.id]);
      await nextTick();

      expect(wrapper.emitted('select-items')).toEqual([
        [
          {
            group_approvers_ids: [2],
          },
        ],
      ]);
    });

    it('emits when a group is deselected', () => {
      findListbox().vm.$emit('select', [group.id]);
      findListbox().vm.$emit('select', []);
      expect(wrapper.emitted('select-items')[1]).toEqual([{ group_approvers_ids: [] }]);
    });
  });

  describe('custom props', () => {
    beforeEach(async () => {
      createComponent({ propsData: { state: false } });
      await waitForApolloAndVue();
    });

    it('displays the correct listbox validation state', () => {
      expect(findListbox().props('state')).toBe(false);
    });
  });

  describe('descendant group approvers', () => {
    it('filters groups when search is performed in listbox', async () => {
      createComponent({ provide: { globalGroupApproversEnabled: false } });
      await waitForApolloAndVue();
      await waitForPromises();

      expect(searchNamespaceGroupsQueryHandlerSuccess).not.toHaveBeenCalled();
      expect(searchDescendantGroupsQueryHandlerSuccess).toHaveBeenCalledTimes(1);
      expect(searchDescendantGroupsQueryHandlerSuccess).toHaveBeenCalledWith({
        rootNamespacePath,
        search: '',
        withCount: false,
      });

      const initialItems = findListbox().props('items');
      expect(initialItems).toHaveLength(3);

      const searchTerm = 'test';
      findListbox().vm.$emit('search', searchTerm);
      await waitForApolloAndVue();

      expect(searchDescendantGroupsQueryHandlerSuccess).toHaveBeenCalledTimes(2);
      expect(searchDescendantGroupsQueryHandlerSuccess).toHaveBeenNthCalledWith(2, {
        rootNamespacePath,
        search: searchTerm,
        withCount: false,
      });
    });

    it('contains the root group and descendent group and filtes out null values', async () => {
      createComponent({ provide: { globalGroupApproversEnabled: false } });
      await waitForApolloAndVue();
      await waitForPromises();

      const items = [
        expect.objectContaining(rootGroup),
        expect.objectContaining(group),
        expect.objectContaining(group2),
      ];
      expect(findListbox().props('items')).toEqual(items);
    });

    it('sets correct toggle text when only approver id is provided', async () => {
      createComponent({ propsData: { selected: [2] } });
      await waitForApolloAndVue();
      await waitForPromises();

      expect(findListbox().props('toggleText')).toBe('Name 2');
    });

    it('sets correct toggle text', async () => {
      createComponent({ propsData: { selected: [2] } });
      await waitForApolloAndVue();
      await waitForPromises();

      expect(findListbox().props('toggleText')).toBe('Name 2');
    });
  });

  describe('render selected names', () => {
    it.each(['path/to/name-2', 'Name 2'])(
      'renders groups selected by name or fullPath',
      async (value) => {
        createComponent({ propsData: { selectedNames: [value] } });
        await waitForApolloAndVue();
        await waitForPromises();

        expect(findListbox().props('selected')).toEqual(['gid://gitlab/Group/2']);
        expect(wrapper.emitted('select-items')).toEqual([[{ group_approvers_ids: [2] }]]);
      },
    );
  });

  describe('when selected is not an array', () => {
    it('renders without crashing and selects nothing', async () => {
      createComponent({ propsData: { selected: null } });
      await waitForApolloAndVue();
      await waitForPromises();

      expect(findListbox().props('selected')).toEqual([]);
    });

    it('renders without crashing when selectedNames is provided', async () => {
      createComponent({ propsData: { selected: null, selectedNames: ['Name 2'] } });
      await waitForApolloAndVue();
      await waitForPromises();

      expect(findListbox().props('selected')).toEqual(['gid://gitlab/Group/2']);
    });
  });

  describe('render selected names and ids', () => {
    it('renders both selected names and ids', async () => {
      createComponent({
        propsData: {
          selectedNames: ['path/to/name-2'],
          selected: [1],
        },
      });

      await waitForApolloAndVue();
      await waitForPromises();

      expect(findListbox().props('selected')).toEqual([
        'gid://gitlab/Group/2',
        'gid://gitlab/Group/1',
      ]);
      expect(wrapper.emitted('select-items')).toEqual([
        [{ group_approvers_ids: [1] }],
        [{ group_approvers_ids: [2, 1] }],
      ]);
    });
  });

  describe('reset groups', () => {
    it('resets all selected groups', async () => {
      createComponent({ propsData: { selectedNames: ['Name 1'] } });
      await waitForApolloAndVue();
      await waitForPromises();

      findListbox().vm.$emit('reset');

      expect(wrapper.emitted('select-items')).toEqual([[{ group_approvers_ids: [] }]]);
    });
  });

  describe('preserving selection', () => {
    it('preserves initial selection after search', async () => {
      createComponent({
        propsData: {
          selected: [group.id],
        },
      });

      await waitForApolloAndVue();
      await waitForPromises();

      expect(findListbox().props('items')).toHaveLength(2);
      expect(findListbox().props('toggleText')).toBe(group.fullName);

      await findListbox().vm.$emit('search', group2.fullName);

      expect(findListbox().props('items')).toHaveLength(1);
      expect(findListbox().props('selected')).toEqual([group.id]);
      await wrapper.findComponentByTestId(`listbox-item-${group2.id}`).vm.$emit('select', true);

      expect(wrapper.emitted('select-items')).toEqual([[{ group_approvers_ids: [2, 3] }]]);
    });
  });

  describe('error handling', () => {
    it('emits error when query fails', async () => {
      createComponent({
        handlers: {
          searchNamespaceGroupsQueryHandler: jest.fn().mockRejectedValue({}),
        },
      });

      await waitForApolloAndVue();
      await waitForPromises();

      expect(wrapper.emitted('error')).toHaveLength(1);
    });
  });
});
