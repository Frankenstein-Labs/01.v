import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { DEBOUNCE_DELAY } from '~/vue_shared/components/filtered_search_bar/constants';
import DashboardFrequentProjects from 'ee/analytics/analytics_dashboards/link_to_dashboards/dashboard_frequent_projects.vue';
import DashboardItemsList from 'ee/analytics/analytics_dashboards/link_to_dashboards/dashboard_items_list.vue';
import currentUserFrecentProjectsQueryWithDashboards from 'ee/analytics/analytics_dashboards/link_to_dashboards/graphql/current_user_frecent_projects_with_dashboards.query.graphql';

Vue.use(VueApollo);

describe('DashboardFrequentProjects', () => {
  let wrapper;
  let mockApollo;

  const mockFrecentProjects = [
    {
      id: 'gid://gitlab/Project/1',
      name: 'Project 1',
      namespace: 'namespace / Project 1',
      avatarUrl: '/avatar1.png',
      fullPath: 'namespace/project-1',
      customizableDashboards: {
        nodes: [{ slug: 'duo_and_sdlc_trends' }],
      },
    },
    {
      id: 'gid://gitlab/Project/2',
      name: 'Project 2',
      namespace: 'namespace / Project 2',
      avatarUrl: '/avatar2.png',
      fullPath: 'namespace/project-2',
      customizableDashboards: {
        nodes: [{ slug: 'value_streams_dashboard' }],
      },
    },
    {
      id: 'gid://gitlab/Project/3',
      name: 'Project 3',
      namespace: 'namespace / Project 3',
      avatarUrl: '/avatar3.png',
      fullPath: 'namespace/project-3',
      customizableDashboards: {
        nodes: [{ slug: 'duo_and_sdlc_trends' }],
      },
    },
  ];

  const frecentProjectsQueryHandler = jest.fn().mockResolvedValue({
    data: {
      frecentProjects: mockFrecentProjects,
    },
  });

  const createComponent = ({ queryHandler = frecentProjectsQueryHandler } = {}) => {
    mockApollo = createMockApollo([[currentUserFrecentProjectsQueryWithDashboards, queryHandler]]);

    wrapper = shallowMountExtended(DashboardFrequentProjects, {
      apolloProvider: mockApollo,
      propsData: {
        dashboardName: 'duo_and_sdlc_trends',
      },
    });
  };

  const findDashboardItemsList = () => wrapper.findComponent(DashboardItemsList);

  const waitForQuery = async () => {
    jest.advanceTimersByTime(DEBOUNCE_DELAY);
    await waitForPromises();
  };

  afterEach(() => {
    wrapper?.destroy();
  });

  describe('when loading', () => {
    it('passes loading state to DashboardItemsList', () => {
      createComponent();

      expect(findDashboardItemsList().props('loading')).toBe(true);
    });
  });

  describe('when loaded', () => {
    beforeEach(async () => {
      createComponent();
      await waitForQuery();
    });

    it('passes loading false to DashboardItemsList', () => {
      expect(findDashboardItemsList().props('loading')).toBe(false);
    });

    it('filters projects to only those with the specified dashboard', () => {
      const items = findDashboardItemsList().props('items');

      expect(items).toHaveLength(2);
      expect(items[0].id).toBe('gid://gitlab/Project/1');
      expect(items[1].id).toBe('gid://gitlab/Project/3');
    });

    it('passes correct props to DashboardItemsList', () => {
      expect(findDashboardItemsList().props()).toMatchObject({
        loading: false,
        emptyStateText: 'Projects you visit often will appear here.',
        groupName: 'Frequently visited projects',
        isGroup: false,
        dashboardName: 'duo_and_sdlc_trends',
      });
    });
  });

  describe('when query returns empty data', () => {
    beforeEach(async () => {
      const emptyQueryHandler = jest.fn().mockResolvedValue({
        data: {
          frecentProjects: [],
        },
      });
      createComponent({ queryHandler: emptyQueryHandler });
      await waitForQuery();
    });

    it('passes empty array to DashboardItemsList', () => {
      expect(findDashboardItemsList().props('items')).toEqual([]);
    });
  });

  describe('when query returns null', () => {
    beforeEach(async () => {
      const nullQueryHandler = jest.fn().mockResolvedValue({
        data: {
          frecentProjects: null,
        },
      });
      createComponent({ queryHandler: nullQueryHandler });
      await waitForQuery();
    });

    it('passes empty array to DashboardItemsList', () => {
      expect(findDashboardItemsList().props('items')).toEqual([]);
    });
  });

  describe('when no projects have the specified dashboard', () => {
    beforeEach(async () => {
      const projectsWithoutDashboard = mockFrecentProjects.map((project) => ({
        ...project,
        customizableDashboards: {
          nodes: [{ slug: 'other_dashboard' }],
        },
      }));

      const queryHandler = jest.fn().mockResolvedValue({
        data: {
          frecentProjects: projectsWithoutDashboard,
        },
      });

      createComponent({ queryHandler });
      await waitForQuery();
    });

    it('passes empty array to DashboardItemsList', () => {
      expect(findDashboardItemsList().props('items')).toEqual([]);
    });
  });
});
