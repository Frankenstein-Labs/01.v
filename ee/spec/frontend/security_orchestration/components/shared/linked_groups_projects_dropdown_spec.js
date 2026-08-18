import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import getSppLinkedGroupsProjects from 'ee/security_orchestration/graphql/queries/get_spp_linked_groups_projects.query.graphql';
import BaseItemsDropdown from 'ee/security_orchestration/components/shared/base_items_dropdown.vue';
import LinkedGroupsProjectsDropdown from 'ee/security_orchestration/components/shared/linked_groups_projects_dropdown.vue';
import ProjectsCountMessage from 'ee/security_orchestration/components/shared/projects_count_message.vue';
import { generateMockProjects } from 'ee_jest/security_orchestration/mocks/mock_data';

describe('LinkedGroupsProjectsDropdown', () => {
  let wrapper;
  let requestHandler;

  const SPP_FULL_PATH = 'security/policy-project';
  const mockAssignedPolicyProject = { fullPath: SPP_FULL_PATH };

  const defaultPageInfo = {
    __typename: 'PageInfo',
    hasNextPage: false,
    hasPreviousPage: false,
    startCursor: null,
    endCursor: null,
  };

  const mockProjectsGroup1 = generateMockProjects([10, 11]);
  const mockProjectsGroup2 = generateMockProjects([20, 21]);
  const allMockProjects = [...mockProjectsGroup1, ...mockProjectsGroup2];

  const mapIds = (nodes) => nodes.map(({ id }) => id);
  const allMockProjectIds = mapIds(allMockProjects);

  const mapItems = (items) =>
    items.map(({ id, name, fullPath }) => ({ value: id, text: name, fullPath }));

  const mockSppLinkedHandler = ({
    projectsGroup1 = mockProjectsGroup1,
    projectsGroup2 = mockProjectsGroup2,
    hasNextPage = false,
    projectsGroup1HasNextPage = false,
    projectsGroup2HasNextPage = false,
  } = {}) => {
    return jest.fn().mockResolvedValue({
      data: {
        project: {
          id: 'gid://gitlab/Project/1',
          securityPolicyProjectLinkedGroups: {
            nodes: [
              {
                id: 'gid://gitlab/Group/1',
                name: 'Group 1',
                fullPath: 'group-1',
                projects: {
                  nodes: projectsGroup1,
                  pageInfo: { hasNextPage: projectsGroup1HasNextPage, endCursor: null },
                },
              },
              {
                id: 'gid://gitlab/Group/2',
                name: 'Group 2',
                fullPath: 'group-2',
                projects: {
                  nodes: projectsGroup2,
                  pageInfo: { hasNextPage: projectsGroup2HasNextPage, endCursor: null },
                },
              },
            ],
            pageInfo: { ...defaultPageInfo, hasNextPage },
          },
        },
      },
    });
  };

  const createMockApolloProvider = (handler) => {
    Vue.use(VueApollo);
    requestHandler = handler;
    return createMockApollo([[getSppLinkedGroupsProjects, requestHandler]]);
  };

  const createComponent = ({
    propsData = {},
    handler = mockSppLinkedHandler(),
    provide = {},
  } = {}) => {
    wrapper = shallowMountExtended(LinkedGroupsProjectsDropdown, {
      apolloProvider: createMockApolloProvider(handler),
      propsData: {
        ...propsData,
      },
      provide: {
        assignedPolicyProject: mockAssignedPolicyProject,
        ...provide,
      },
    });
  };

  const findDropdown = () => wrapper.findComponent(BaseItemsDropdown);
  const findFooter = () => wrapper.findComponent(ProjectsCountMessage);

  describe('loading state', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders loading state', () => {
      expect(findDropdown().props('loading')).toBe(true);
    });

    it('loads items from all linked groups', async () => {
      await waitForPromises();

      expect(findDropdown().props('loading')).toBe(false);
      expect(findDropdown().props('items')).toEqual(mapItems(allMockProjects));
    });
  });

  describe('selection', () => {
    it.each`
      event           | description
      ${'select'}     | ${'select event'}
      ${'select-all'} | ${'select-all event'}
      ${'reset'}      | ${'reset event'}
    `('emits select when dropdown emits $description', async ({ event }) => {
      createComponent();
      await waitForPromises();

      const payload = event === 'reset' ? undefined : allMockProjectIds;
      findDropdown().vm.$emit(event, payload);

      expect(wrapper.emitted('select')).toHaveLength(1);
      if (event === 'reset') {
        expect(wrapper.emitted('select')[0][0]).toEqual([]);
      } else {
        expect(wrapper.emitted('select')[0][0]).toHaveLength(allMockProjects.length);
      }
    });

    it('renders selected items', async () => {
      createComponent({
        propsData: {
          selected: allMockProjectIds,
        },
      });

      await waitForPromises();

      expect(findDropdown().props('selected')).toEqual(allMockProjectIds);
    });
  });

  describe('project count', () => {
    it('shows footer when withProjectCount is true', async () => {
      createComponent({
        propsData: {
          withProjectCount: true,
        },
      });

      await waitForPromises();

      expect(findFooter().exists()).toBe(true);
    });

    it('calculates total count from deduplicated projects', async () => {
      createComponent({
        propsData: {
          withProjectCount: true,
        },
      });

      await waitForPromises();

      expect(findFooter().props('totalCount')).toBe(allMockProjects.length);
    });
  });

  describe('error handling', () => {
    it('emits error when query fails', async () => {
      const errorHandler = jest.fn().mockRejectedValue(new Error('Query failed'));
      createComponent({ handler: errorHandler });

      await waitForPromises();

      expect(wrapper.emitted('projects-query-error')).toHaveLength(1);
    });
  });

  describe('pagination', () => {
    it('fetches more items when bottom reached', async () => {
      createComponent({
        handler: mockSppLinkedHandler({ hasNextPage: true }),
      });
      await waitForPromises();

      expect(findDropdown().props('infiniteScroll')).toBe(true);

      findDropdown().vm.$emit('bottom-reached');

      expect(requestHandler).toHaveBeenCalledTimes(2);
    });

    it('does not enable infinite scroll when all items are loaded', async () => {
      createComponent({
        handler: mockSppLinkedHandler({ hasNextPage: false }),
      });
      await waitForPromises();

      expect(findDropdown().props('infiniteScroll')).toBe(false);
    });
  });

  describe('search', () => {
    it('always sends search term to the backend on initial load', async () => {
      createComponent();
      await waitForPromises();

      expect(requestHandler).toHaveBeenCalledWith(
        expect.objectContaining({ fullPath: SPP_FULL_PATH, search: '' }),
      );
    });

    it('re-runs the query with the search term when user searches', async () => {
      createComponent();
      await waitForPromises();

      findDropdown().vm.$emit('search', 'project-25');
      await waitForPromises();

      expect(requestHandler).toHaveBeenLastCalledWith(
        expect.objectContaining({ fullPath: SPP_FULL_PATH, search: 'project-25' }),
      );
    });

    it('performs server-side search even when all groups are loaded but inner projects have more pages', async () => {
      // Regression: a group can have more than 20 projects. The outer pageInfo only
      // paginates groups; inner project pagination is tracked separately. Searching
      // must always hit the backend.
      createComponent({
        handler: mockSppLinkedHandler({ hasNextPage: false, projectsGroup1HasNextPage: true }),
      });
      await waitForPromises();

      expect(requestHandler).toHaveBeenCalledTimes(1);

      findDropdown().vm.$emit('search', 'project-99');
      await waitForPromises();

      expect(requestHandler).toHaveBeenCalledTimes(2);
      expect(requestHandler).toHaveBeenLastCalledWith(
        expect.objectContaining({ search: 'project-99' }),
      );
    });
  });

  describe('allProjectsLoaded / info icon', () => {
    it('hides info icon when all groups and all inner projects are loaded', async () => {
      createComponent({
        propsData: { withProjectCount: true },
        handler: mockSppLinkedHandler({ hasNextPage: false }),
      });
      await waitForPromises();

      expect(findFooter().props('showInfoIcon')).toBe(false);
    });

    it('shows info icon when there are more groups to load', async () => {
      createComponent({
        propsData: { withProjectCount: true },
        handler: mockSppLinkedHandler({ hasNextPage: true }),
      });
      await waitForPromises();

      expect(findFooter().props('showInfoIcon')).toBe(true);
    });

    it('shows info icon when a group has more than 20 projects (inner projects have next page)', async () => {
      createComponent({
        propsData: { withProjectCount: true },
        handler: mockSppLinkedHandler({ hasNextPage: false, projectsGroup1HasNextPage: true }),
      });
      await waitForPromises();

      expect(findFooter().props('showInfoIcon')).toBe(true);
    });

    it('hides footer entirely while search is active (F1: totalCount irrelevant during search)', async () => {
      createComponent({
        propsData: { withProjectCount: true },
        handler: mockSppLinkedHandler({ hasNextPage: false }),
      });
      await waitForPromises();

      expect(findFooter().exists()).toBe(true);

      findDropdown().vm.$emit('search', 'foo');
      await waitForPromises();

      expect(findFooter().exists()).toBe(false);
    });

    it('preserves hasMoreProjectsInGroups=true during search even when search response has no next page (F2)', async () => {
      // A group has >20 projects (projectsGroup1HasNextPage: true on initial load).
      // When the user searches and the search result for that group has <20 matches,
      // the response returns hasNextPage: false. hasMoreProjectsInGroups must stay
      // true — the search being short doesn't mean the group shrank.
      const searchHandler = jest
        .fn()
        .mockResolvedValueOnce({
          data: {
            project: {
              id: 'gid://gitlab/Project/1',
              securityPolicyProjectLinkedGroups: {
                nodes: [
                  {
                    id: 'gid://gitlab/Group/1',
                    name: 'Group 1',
                    fullPath: 'group-1',
                    projects: {
                      nodes: mockProjectsGroup1,
                      pageInfo: { hasNextPage: true, endCursor: null },
                    },
                  },
                ],
                pageInfo: { ...defaultPageInfo, hasNextPage: false },
              },
            },
          },
        })
        .mockResolvedValueOnce({
          data: {
            project: {
              id: 'gid://gitlab/Project/1',
              securityPolicyProjectLinkedGroups: {
                nodes: [
                  {
                    id: 'gid://gitlab/Group/1',
                    name: 'Group 1',
                    fullPath: 'group-1',
                    projects: {
                      nodes: [mockProjectsGroup1[0]],
                      pageInfo: { hasNextPage: false, endCursor: null },
                    },
                  },
                ],
                pageInfo: { ...defaultPageInfo, hasNextPage: false },
              },
            },
          },
        });

      createComponent({ handler: searchHandler });
      await waitForPromises();

      // After initial load allProjectsLoaded is false (inner projects have next page)
      expect(wrapper.vm.allProjectsLoaded).toBe(false);

      findDropdown().vm.$emit('search', 'specific');
      await waitForPromises();

      // Search response returns hasNextPage: false, but allProjectsLoaded must
      // stay false because we know from the initial load the group has >20 projects.
      expect(wrapper.vm.allProjectsLoaded).toBe(false);
      expect(wrapper.vm.hasMoreProjectsInGroups).toBe(true);
    });
  });

  describe('group filtering', () => {
    it('filters projects by group ids', async () => {
      // Projects from group 1 have group.id set by the handler to 'gid://gitlab/Group/1'
      createComponent({
        propsData: {
          groupIds: ['gid://gitlab/Group/1'],
        },
      });
      await waitForPromises();

      // Only projects from the first group should be shown
      expect(findDropdown().props('items')).toHaveLength(mockProjectsGroup1.length);
    });
  });

  describe('when assignedPolicyProject is not provided', () => {
    it('skips the query', async () => {
      createComponent({
        provide: {
          assignedPolicyProject: null,
        },
      });

      await waitForPromises();

      expect(requestHandler).not.toHaveBeenCalled();
    });
  });

  describe('fetching pre-selected projects', () => {
    it('fetches projects by ids when selected projects are not loaded', async () => {
      const notLoadedProjectId = 'gid://gitlab/Project/999';
      createComponent({
        propsData: {
          selected: [notLoadedProjectId],
        },
      });

      await waitForPromises();

      expect(requestHandler).toHaveBeenCalledWith(
        expect.objectContaining({
          projectIds: [notLoadedProjectId],
        }),
      );
    });
  });
});
