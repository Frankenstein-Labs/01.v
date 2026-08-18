import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import getSppEligibleProjects from 'ee/security_orchestration/graphql/queries/get_spp_eligible_projects.query.graphql';
import BaseItemsDropdown from 'ee/security_orchestration/components/shared/base_items_dropdown.vue';
import EligibleProjectsDropdown from 'ee/security_orchestration/components/shared/eligible_projects_dropdown.vue';
import ProjectsCountMessage from 'ee/security_orchestration/components/shared/projects_count_message.vue';
import { generateMockProjects } from 'ee_jest/security_orchestration/mocks/mock_data';

describe('EligibleProjectsDropdown', () => {
  let wrapper;
  let eligibleHandler;

  const SPP_FULL_PATH = 'security/policy-project';
  const mockAssignedPolicyProject = { fullPath: SPP_FULL_PATH };

  const defaultPageInfo = {
    __typename: 'PageInfo',
    hasNextPage: false,
    hasPreviousPage: false,
    startCursor: null,
    endCursor: null,
  };

  const mockProjects = generateMockProjects([10, 11, 20, 21]);
  const mapIds = (nodes) => nodes.map(({ id }) => id);
  const allMockProjectIds = mapIds(mockProjects);

  const mapItems = (items) =>
    items.map(({ id, name, fullPath }) => ({ value: id, text: name, fullPath }));

  const mockEligibleProjectsHandler = ({
    projects = mockProjects,
    hasNextPage = false,
    endCursor = null,
  } = {}) => {
    return jest.fn().mockResolvedValue({
      data: {
        project: {
          id: 'gid://gitlab/Project/1',
          securityPolicyEligibleProjects: {
            nodes: projects,
            pageInfo: { ...defaultPageInfo, hasNextPage, endCursor },
          },
        },
      },
    });
  };

  const createMockApolloProvider = (handler) => {
    Vue.use(VueApollo);
    eligibleHandler = handler;
    return createMockApollo([[getSppEligibleProjects, eligibleHandler]]);
  };

  const createComponent = ({
    propsData = {},
    handler = mockEligibleProjectsHandler(),
    provide = {},
  } = {}) => {
    wrapper = shallowMountExtended(EligibleProjectsDropdown, {
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

    it('loads eligible projects', async () => {
      await waitForPromises();

      expect(findDropdown().props('loading')).toBe(false);
      expect(findDropdown().props('items')).toEqual(mapItems(mockProjects));
    });
  });

  describe('query variables', () => {
    it('passes SPP fullPath and empty search to the query on initial load', async () => {
      createComponent();
      await waitForPromises();

      expect(eligibleHandler).toHaveBeenCalledWith(
        expect.objectContaining({ fullPath: SPP_FULL_PATH, search: '' }),
      );
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
        expect(wrapper.emitted('select')[0][0]).toHaveLength(mockProjects.length);
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
        propsData: { withProjectCount: true },
      });

      await waitForPromises();

      expect(findFooter().exists()).toBe(true);
    });

    it('shows total count of loaded projects', async () => {
      createComponent({
        propsData: { withProjectCount: true },
      });

      await waitForPromises();

      expect(findFooter().props('totalCount')).toBe(mockProjects.length);
    });

    it('hides info icon when no more pages remain', async () => {
      createComponent({
        propsData: { withProjectCount: true },
        handler: mockEligibleProjectsHandler({ hasNextPage: false }),
      });
      await waitForPromises();

      expect(findFooter().props('showInfoIcon')).toBe(false);
    });

    it('shows info icon when there are more pages to load', async () => {
      createComponent({
        propsData: { withProjectCount: true },
        handler: mockEligibleProjectsHandler({ hasNextPage: true }),
      });
      await waitForPromises();

      expect(findFooter().props('showInfoIcon')).toBe(true);
    });

    it('hides footer entirely while search is active', async () => {
      createComponent({
        propsData: { withProjectCount: true },
      });
      await waitForPromises();

      expect(findFooter().exists()).toBe(true);

      findDropdown().vm.$emit('search', 'foo');
      await waitForPromises();

      expect(findFooter().exists()).toBe(false);
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
        handler: mockEligibleProjectsHandler({ hasNextPage: true, endCursor: 'cursor1' }),
      });
      await waitForPromises();

      expect(findDropdown().props('infiniteScroll')).toBe(true);

      findDropdown().vm.$emit('bottom-reached');
      await waitForPromises();

      expect(eligibleHandler).toHaveBeenCalledTimes(2);
      expect(eligibleHandler).toHaveBeenLastCalledWith(
        expect.objectContaining({ after: 'cursor1' }),
      );
    });

    it('does not enable infinite scroll when all items are loaded', async () => {
      createComponent({
        handler: mockEligibleProjectsHandler({ hasNextPage: false }),
      });
      await waitForPromises();

      expect(findDropdown().props('infiniteScroll')).toBe(false);
    });

    it('emits projects-query-error when fetchMore rejects', async () => {
      const handler = jest
        .fn()
        .mockResolvedValueOnce({
          data: {
            project: {
              id: 'gid://gitlab/Project/1',
              securityPolicyEligibleProjects: {
                nodes: mockProjects,
                pageInfo: { ...defaultPageInfo, hasNextPage: true, endCursor: 'cursor1' },
              },
            },
          },
        })
        .mockRejectedValueOnce(new Error('fetchMore failed'));

      createComponent({ handler });
      await waitForPromises();

      findDropdown().vm.$emit('bottom-reached');
      await waitForPromises();

      expect(wrapper.emitted('projects-query-error')).toHaveLength(1);
    });
  });

  describe('search', () => {
    it('re-runs the query with the search term when user searches', async () => {
      createComponent();
      await waitForPromises();

      findDropdown().vm.$emit('search', 'project-25');
      await waitForPromises();

      expect(eligibleHandler).toHaveBeenLastCalledWith(
        expect.objectContaining({ fullPath: SPP_FULL_PATH, search: 'project-25' }),
      );
    });
  });

  describe('hydrating already-selected projects', () => {
    const buildEligibleResponse = (projects) => ({
      data: {
        project: {
          id: 'gid://gitlab/Project/1',
          securityPolicyEligibleProjects: {
            nodes: projects,
            pageInfo: defaultPageInfo,
          },
        },
      },
    });

    const createSwitchingHandler = (byIdsProjects) =>
      jest
        .fn()
        .mockImplementation((variables) =>
          Promise.resolve(buildEligibleResponse(variables.ids ? byIdsProjects : mockProjects)),
        );

    it('re-queries by ids when selected ids are not in the current page', async () => {
      const offPageProjects = generateMockProjects([99]);
      const offPageIds = mapIds(offPageProjects);
      const handler = createSwitchingHandler(offPageProjects);

      createComponent({
        propsData: { selected: offPageIds },
        handler,
      });
      await waitForPromises();

      const byIdsCalls = handler.mock.calls.filter(([vars]) => vars.ids !== undefined);
      expect(byIdsCalls).toHaveLength(1);
      expect(byIdsCalls[0][0]).toMatchObject({
        fullPath: SPP_FULL_PATH,
        ids: offPageIds,
      });
    });

    it('does not re-query by ids when all selected ids are already loaded', async () => {
      const handler = createSwitchingHandler([]);

      createComponent({
        propsData: { selected: allMockProjectIds },
        handler,
      });
      await waitForPromises();

      const byIdsCalls = handler.mock.calls.filter(([vars]) => vars.ids !== undefined);
      expect(byIdsCalls).toHaveLength(0);
    });

    it('emits projects-query-error when the by-ids lookup fails', async () => {
      const handler = jest.fn().mockImplementation((variables) => {
        if (variables.ids) return Promise.reject(new Error('lookup failed'));
        return Promise.resolve(buildEligibleResponse(mockProjects));
      });

      createComponent({
        propsData: { selected: ['gid://gitlab/Project/9999'] },
        handler,
      });
      await waitForPromises();

      expect(wrapper.emitted('projects-query-error')).toHaveLength(1);
    });

    it('drops ids the by-ids response does not return (no longer eligible)', async () => {
      const stillEligibleProjects = generateMockProjects([99]);
      const stillEligibleId = mapIds(stillEligibleProjects)[0];
      const noLongerEligibleId = 'gid://gitlab/Project/100';
      const selected = [stillEligibleId, noLongerEligibleId];
      const handler = createSwitchingHandler(stillEligibleProjects);

      createComponent({
        propsData: { selected },
        handler,
      });
      await waitForPromises();

      expect(findDropdown().props('selected')).toEqual([stillEligibleId]);
      expect(findDropdown().props('selected')).not.toContain(noLongerEligibleId);
    });
  });

  describe('when assignedPolicyProject is not provided', () => {
    it('skips the query', async () => {
      createComponent({
        provide: { assignedPolicyProject: null },
      });
      await waitForPromises();

      expect(eligibleHandler).not.toHaveBeenCalled();
    });
  });
});
