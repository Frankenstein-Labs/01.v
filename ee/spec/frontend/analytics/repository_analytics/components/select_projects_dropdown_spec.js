import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import { GlCollapsibleListbox, GlIntersectionObserver } from '@gitlab/ui';
import getGroupProjects from 'ee/analytics/repository_analytics/graphql/queries/get_group_projects.query.graphql';
import SelectProjectsDropdown from 'ee/analytics/repository_analytics/components/select_projects_dropdown.vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';

describe('Select projects dropdown component', () => {
  let wrapper;
  let requestHandlers;

  const defaultNodes = [
    { id: 1, name: '1' },
    { id: 2, name: '2' },
  ];

  const defaultPageInfo = {
    __typename: 'PageInfo',
    hasNextPage: false,
    hasPreviousPage: false,
    startCursor: null,
    endCursor: null,
  };

  const mockApolloHandlers = (nodes = defaultNodes, hasNextPage = false) => {
    return {
      getGroupProjects: jest.fn().mockResolvedValue({
        data: {
          id: 1,
          group: {
            id: 2,
            projects: {
              nodes,
              pageInfo: { ...defaultPageInfo, hasNextPage },
            },
          },
        },
      }),
    };
  };
  const createMockApolloProvider = (handlers) => {
    Vue.use(VueApollo);

    requestHandlers = handlers;
    return createMockApollo([[getGroupProjects, requestHandlers.getGroupProjects]]);
  };

  const findDropdown = () => wrapper.findComponent(GlCollapsibleListbox);
  const selectAllProjects = () => findDropdown().vm.$emit('select-all');
  const resetAllProjects = () => findDropdown().vm.$emit('reset');
  const selectProjectById = (id) => findDropdown(id).vm.$emit('select', id);
  const findIntersectionObserver = () => wrapper.findComponent(GlIntersectionObserver);

  const createComponent = ({ handlers = mockApolloHandlers() } = {}) => {
    wrapper = shallowMountExtended(SelectProjectsDropdown, {
      apolloProvider: createMockApolloProvider(handlers),
      provide: {
        groupFullPath: 'gitlab-org',
      },
      stubs: { GlCollapsibleListbox },
    });
  };

  describe('when selecting all project', () => {
    beforeEach(async () => {
      createComponent({ handlers: mockApolloHandlers([{ id: 1, name: '1', isSelected: true }]) });
      await waitForPromises();
    });

    it('should reset all selected projects', async () => {
      resetAllProjects();

      await nextTick();

      expect(findDropdown().props('selected')).toEqual([]);
      expect(wrapper.emitted('reset-all-projects')).toEqual([[[]]]);
    });

    it('should emit select-all-projects event', () => {
      selectAllProjects();

      expect(findDropdown().props('items')).toHaveLength(1);
      expect(wrapper.emitted('select-all-projects')).toMatchObject([[[1]]]);
    });
  });

  describe('when selecting a project', () => {
    const initialData = {
      groupProjects: [{ id: 1, name: '1' }],
    };

    beforeEach(async () => {
      createComponent({
        handlers: mockApolloHandlers(initialData.groupProjects, true),
      });
      await waitForPromises();
    });

    it('should check selected project', async () => {
      const project = initialData.groupProjects[0];

      selectProjectById([project.id]);

      await nextTick();
      expect(findDropdown().props('selected')).toEqual([project.id]);
    });

    it('should emit select-project event', () => {
      const project = initialData.groupProjects[0];
      selectProjectById([project.id]);
      expect(wrapper.emitted('select-project')).toMatchObject([[[project.id]]]);
    });
  });

  describe('when there is only one page of projects', () => {
    it('should not render the intersection observer component', async () => {
      createComponent();
      await waitForPromises();
      expect(findIntersectionObserver().exists()).toBe(false);
    });
  });

  describe('when there is more than a page of projects', () => {
    beforeEach(async () => {
      createComponent({ handlers: mockApolloHandlers(defaultNodes, true) });
      await waitForPromises();
    });

    it('should render the intersection observer component', () => {
      expect(findIntersectionObserver().exists()).toBe(true);
    });

    describe('when the intersection observer component appears in view', () => {
      beforeEach(async () => {
        createComponent({ handlers: mockApolloHandlers([], true) });
        await waitForPromises();
      });

      it('makes a query to fetch more projects', () => {
        findDropdown().vm.$emit('bottom-reached');
        expect(requestHandlers.getGroupProjects).toHaveBeenCalledTimes(2);
      });

      describe('when the fetchMore query throws an error', () => {
        it('emits an error event', async () => {
          createComponent({
            handlers: {
              getGroupProjects: jest.fn().mockRejectedValue({}),
            },
          });
          await waitForPromises();
          expect(wrapper.emitted('projects-query-error')).toHaveLength(1);
        });
      });
    });

    describe('when a query is loading a new page of projects', () => {
      it('should render the loading spinner', async () => {
        createComponent({ handlers: mockApolloHandlers([], true) });
        await waitForPromises();

        findDropdown().vm.$emit('bottom-reached');
        await nextTick();

        expect(findDropdown().props('loading')).toBe(true);
      });
    });
  });
});
