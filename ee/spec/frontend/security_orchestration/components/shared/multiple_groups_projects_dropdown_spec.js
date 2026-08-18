import Vue from 'vue';
import VueApollo from 'vue-apollo';
import MultipleGroupsProjectsDropdown from 'ee/security_orchestration/components/shared/multiple_groups_projects_dropdown.vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import getSppLinkedPGroupsChildrenProjects from 'ee/security_orchestration/graphql/queries/get_spp_linked_groups_children_projects.query.graphql';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { defaultPageInfo } from 'ee_jest/security_orchestration/mocks/mock_apollo';
import BaseItemsDropdown from 'ee/security_orchestration/components/shared/base_items_dropdown.vue';

describe('MultipleGroupsProjectsDropdown', () => {
  let wrapper;
  let requestHandler;

  const groups = [
    {
      id: '1',
      name: 'group1',
      fullPath: 'fullPath1',
      projects: {
        nodes: [
          {
            id: '1',
            name: 'project1',
            fullPath: 'group1/project1',
            group: {
              id: '1',
            },
          },
          {
            id: '2',
            name: 'project2',
            fullPath: 'group1/project2',
            group: {
              id: '1',
            },
          },
        ],
        pageInfo: defaultPageInfo,
      },
    },
    {
      id: '2',
      name: 'group2',
      fullPath: 'fullPath2',
      projects: {
        nodes: [
          {
            id: '3',
            name: 'project3',
            fullPath: 'group2/project3',
            group: {
              id: '2',
            },
          },
          {
            id: '4',
            name: 'project4',
            fullPath: 'group2/project4',
            group: {
              id: '2',
            },
          },
        ],
        pageInfo: defaultPageInfo,
      },
    },
  ];

  const groupIds = [groups[0].id, groups[1].id];
  const allProjects = groups.flatMap((group) => group.projects.nodes);
  const allProjectsListBoxItems = allProjects.map(({ id, fullPath, name }) => ({
    text: name,
    value: id,
    fullPath,
  }));

  const mockRequestHandler = (items = []) =>
    jest.fn().mockResolvedValue({
      data: {
        groups: {
          nodes: items,
          pageInfo: defaultPageInfo,
        },
      },
    });

  const createMockApolloProvider = (handler) => {
    Vue.use(VueApollo);
    requestHandler = handler;

    return createMockApollo([[getSppLinkedPGroupsChildrenProjects, requestHandler]]);
  };

  const createComponent = ({ propsData, handler = mockRequestHandler(groups) } = {}) => {
    wrapper = shallowMountExtended(MultipleGroupsProjectsDropdown, {
      apolloProvider: createMockApolloProvider(handler),
      propsData: {
        groupIds,
        ...propsData,
      },
    });
  };

  const findDropdown = () => wrapper.findComponent(BaseItemsDropdown);

  describe('default rendering', () => {
    it('renders a dropdown with project list', async () => {
      createComponent();
      await waitForPromises();

      expect(findDropdown().props('items')).toEqual(allProjectsListBoxItems);
      expect(findDropdown().props('variant')).toBe('default');
      expect(findDropdown().props('category')).toBe('primary');
    });

    it('renders a dropdown with project list that belong to selected groups', async () => {
      createComponent({
        propsData: {
          groupIds: [groupIds[0]],
        },
      });
      await waitForPromises();

      expect(findDropdown().props('items')).toEqual(allProjectsListBoxItems.slice(0, 2));
    });
  });

  describe('search', () => {
    beforeEach(() => {
      createComponent();
    });

    it('searches by text and trims spaces', async () => {
      const testValue = `${allProjects[1].name}   `;
      await waitForPromises();

      await findDropdown().vm.$emit('search', testValue);
      expect(findDropdown().props('items')).toEqual([allProjectsListBoxItems[1]]);
    });

    it('searches by fullPath', async () => {
      await waitForPromises();

      await findDropdown().vm.$emit('search', allProjects[0].fullPath);
      expect(findDropdown().props('items')).toEqual([allProjectsListBoxItems[0]]);
    });
  });

  describe('selection', () => {
    const ids = [allProjects[0].id, allProjects[2].id];

    it('selects projects', async () => {
      createComponent();
      await waitForPromises();

      await findDropdown().vm.$emit('select', allProjectsListBoxItems[0].value);

      expect(wrapper.emitted('select')[1]).toEqual([[allProjects[0]]]);
    });

    it('removes projects from selection when number of selected groups is reduced', async () => {
      createComponent({
        propsData: {
          selected: ids,
        },
      });
      await waitForPromises();

      expect(findDropdown().props('selected')).toEqual(ids);

      await wrapper.setProps({ groupIds: [groupIds[0]] });

      expect(wrapper.emitted('select')[1]).toEqual([[allProjects[0]]]);
    });

    it('removes projects from selection if they do not belong to parent group', async () => {
      createComponent({
        propsData: {
          selected: ids,
          groupIds: [groupIds[0]],
        },
      });
      await waitForPromises();

      expect(wrapper.emitted('select')).toEqual([[[allProjects[0]]]]);
    });
  });

  describe('secondary appearance properties', () => {
    it('renders error state', async () => {
      createComponent({
        propsData: {
          hasError: true,
        },
      });
      await waitForPromises();

      expect(findDropdown().props('variant')).toBe('danger');
      expect(findDropdown().props('category')).toBe('secondary');
    });

    it('renders disabled state and placement', async () => {
      createComponent({
        propsData: {
          placement: 'top',
          disabled: true,
        },
      });
      await waitForPromises();

      expect(findDropdown().props('placement')).toBe('top');
      expect(findDropdown().props('disabled')).toBe(true);
    });
  });
});
