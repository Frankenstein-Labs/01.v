import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import { GlLoadingIcon } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { DEBOUNCE_DELAY } from '~/vue_shared/components/filtered_search_bar/constants';
import DashboardSearchResults from 'ee/analytics/analytics_dashboards/link_to_dashboards/dashboard_search_results.vue';
import DashboardItemsList from 'ee/analytics/analytics_dashboards/link_to_dashboards/dashboard_items_list.vue';
import searchProjectsQueryWithDashboards from 'ee/analytics/analytics_dashboards/link_to_dashboards/graphql/search_projects_with_dashboards.query.graphql';
import searchGroupsQueryWithDashboards from 'ee/analytics/analytics_dashboards/link_to_dashboards/graphql/search_groups_with_dashboards.query.graphql';

Vue.use(VueApollo);

describe('DashboardSearchResults', () => {
  let wrapper;
  let mockApollo;

  const mockProjects = [
    {
      id: 'gid://gitlab/Project/1',
      name: 'Project 1',
      nameWithNamespace: 'namespace / Project 1',
      avatarUrl: '/avatar1.png',
      fullPath: 'namespace/project-1',
      customizableDashboards: {
        nodes: [{ slug: 'duo_and_sdlc_trends' }],
      },
    },
    {
      id: 'gid://gitlab/Project/2',
      name: 'Project 2',
      nameWithNamespace: 'namespace / Project 2',
      avatarUrl: '/avatar2.png',
      fullPath: 'namespace/project-2',
      customizableDashboards: {
        nodes: [{ slug: 'value_streams_dashboard' }],
      },
    },
  ];

  const mockGroups = [
    {
      id: 'gid://gitlab/Group/1',
      name: 'Group 1',
      fullName: 'namespace / Group 1',
      avatarUrl: '/avatar1.png',
      fullPath: 'namespace/group-1',
      customizableDashboards: {
        nodes: [{ slug: 'duo_and_sdlc_trends' }],
      },
    },
    {
      id: 'gid://gitlab/Group/2',
      name: 'Group 2',
      fullName: 'namespace / Group 2',
      avatarUrl: '/avatar2.png',
      fullPath: 'namespace/group-2',
      customizableDashboards: {
        nodes: [{ slug: 'value_streams_dashboard' }],
      },
    },
  ];

  const projectsQueryHandler = jest.fn().mockResolvedValue({
    data: {
      projects: {
        nodes: mockProjects,
      },
    },
  });

  const groupsQueryHandler = jest.fn().mockResolvedValue({
    data: {
      currentUser: {
        id: 'gid://gitlab/User/1',
        groups: {
          nodes: mockGroups,
        },
      },
    },
  });

  const createComponent = ({
    searchTerm = 'test',
    projectsHandler = projectsQueryHandler,
    groupsHandler = groupsQueryHandler,
  } = {}) => {
    mockApollo = createMockApollo([
      [searchProjectsQueryWithDashboards, projectsHandler],
      [searchGroupsQueryWithDashboards, groupsHandler],
    ]);

    wrapper = shallowMountExtended(DashboardSearchResults, {
      apolloProvider: mockApollo,
      propsData: {
        searchTerm,
        dashboardName: 'duo_and_sdlc_trends',
      },
    });
  };

  const findLoadingIcon = () => wrapper.findComponent(GlLoadingIcon);
  const findDashboardItemsLists = () => wrapper.findAllComponents(DashboardItemsList);
  const findMinCharactersMessage = () => wrapper.findByText('Type at least 2 characters to search');
  const findNoResultsMessage = () => wrapper.findByText('No projects or groups found');
  const findStatusElement = () => wrapper.findByRole('status');

  const waitForQuery = async () => {
    jest.advanceTimersByTime(DEBOUNCE_DELAY);
    await waitForPromises();
  };

  afterEach(() => {
    wrapper?.destroy();
  });

  describe('when search term is less than 2 characters', () => {
    it('shows minimum characters message', () => {
      createComponent({ searchTerm: 'a' });

      expect(findMinCharactersMessage().exists()).toBe(true);
      expect(findLoadingIcon().exists()).toBe(false);
      expect(findDashboardItemsLists()).toHaveLength(0);
    });

    it('does not execute queries', () => {
      createComponent({ searchTerm: 'a' });

      expect(projectsQueryHandler).not.toHaveBeenCalled();
      expect(groupsQueryHandler).not.toHaveBeenCalled();
    });

    it('shows correct status text for screen readers', () => {
      createComponent({ searchTerm: 'a' });

      const statusElement = findStatusElement();
      expect(statusElement.text()).toBe('Type at least 2 characters to search');
      expect(statusElement.attributes('aria-atomic')).toBe('true');
      expect(statusElement.classes()).toContain('gl-sr-only');
    });
  });

  describe('when search term is empty', () => {
    it('shows minimum characters message', () => {
      createComponent({ searchTerm: '' });

      expect(findMinCharactersMessage().exists()).toBe(true);
    });

    it('does not execute queries', () => {
      createComponent({ searchTerm: '' });

      expect(projectsQueryHandler).not.toHaveBeenCalled();
      expect(groupsQueryHandler).not.toHaveBeenCalled();
    });
  });

  describe('when loading', () => {
    it('shows loading icon', async () => {
      createComponent();
      jest.advanceTimersByTime(DEBOUNCE_DELAY);
      await nextTick();

      expect(findLoadingIcon().exists()).toBe(true);
      expect(findDashboardItemsLists()).toHaveLength(0);
    });

    it('shows loading status text for screen readers', async () => {
      createComponent();
      jest.advanceTimersByTime(DEBOUNCE_DELAY);
      await nextTick();

      const statusElement = findStatusElement();
      expect(statusElement.text()).toBe('Searching for groups and projects');
    });
  });

  describe('when loaded with results', () => {
    beforeEach(async () => {
      createComponent({ searchTerm: 'test' });
      await waitForQuery();
    });

    it('hides loading icon', () => {
      expect(findLoadingIcon().exists()).toBe(false);
    });

    it('filters projects to only those with the specified dashboard', () => {
      const projectsList = findDashboardItemsLists().at(0);
      const items = projectsList.props('items');

      expect(items).toHaveLength(1);
      expect(items[0].id).toBe('gid://gitlab/Project/1');
    });

    it('filters groups to only those with the specified dashboard', () => {
      const groupsList = findDashboardItemsLists().at(1);
      const items = groupsList.props('items');

      expect(items).toHaveLength(1);
      expect(items[0].id).toBe('gid://gitlab/Group/1');
    });

    it('renders DashboardItemsList for projects with correct props', () => {
      const projectsList = findDashboardItemsLists().at(0);

      expect(projectsList.props()).toMatchObject({
        loading: false,
        emptyStateText: 'No projects found',
        groupName: "Projects I'm a member of",
        isGroup: false,
        dashboardName: 'duo_and_sdlc_trends',
      });
    });

    it('renders DashboardItemsList for groups with correct props', () => {
      const groupsList = findDashboardItemsLists().at(1);

      expect(groupsList.props()).toMatchObject({
        loading: false,
        emptyStateText: 'No groups found',
        groupName: "Groups I'm a member of",
        isGroup: true,
        dashboardName: 'duo_and_sdlc_trends',
      });
      expect(groupsList.attributes('bordered')).toBeDefined();
      expect(groupsList.classes()).toContain('gl-mt-3');
    });

    it('formats project items correctly', () => {
      const projectsList = findDashboardItemsLists().at(0);
      const items = projectsList.props('items');

      expect(items[0]).toEqual({
        id: 'gid://gitlab/Project/1',
        name: 'Project 1',
        namespace: 'namespace / Project 1',
        avatarUrl: '/avatar1.png',
        fullPath: 'namespace/project-1',
      });
    });

    it('formats group items correctly', () => {
      const groupsList = findDashboardItemsLists().at(1);
      const items = groupsList.props('items');

      expect(items[0]).toEqual({
        id: 'gid://gitlab/Group/1',
        name: 'Group 1',
        namespace: 'namespace / Group 1',
        avatarUrl: '/avatar1.png',
        fullPath: 'namespace/group-1',
      });
    });

    it('shows results count status text for screen readers', () => {
      const statusElement = findStatusElement();
      expect(statusElement.text()).toBe('Search found 1 groups and 1 projects');
    });
  });

  describe('when no results found', () => {
    beforeEach(async () => {
      const emptyProjectsHandler = jest.fn().mockResolvedValue({
        data: {
          projects: {
            nodes: [],
          },
        },
      });

      const emptyGroupsHandler = jest.fn().mockResolvedValue({
        data: {
          currentUser: {
            id: 'gid://gitlab/User/1',
            groups: {
              nodes: [],
            },
          },
        },
      });

      createComponent({
        searchTerm: 'nonexistent',
        projectsHandler: emptyProjectsHandler,
        groupsHandler: emptyGroupsHandler,
      });
      jest.advanceTimersByTime(DEBOUNCE_DELAY);
      await waitForPromises();
    });

    it('shows no results message', () => {
      expect(findNoResultsMessage().exists()).toBe(true);
      expect(findDashboardItemsLists()).toHaveLength(0);
    });

    it('shows no results status text for screen readers', () => {
      const statusElement = findStatusElement();
      expect(statusElement.text()).toBe('No projects or groups found');
    });
  });

  describe('when only projects have results', () => {
    beforeEach(async () => {
      const emptyGroupsHandler = jest.fn().mockResolvedValue({
        data: {
          currentUser: {
            id: 'gid://gitlab/User/1',
            groups: {
              nodes: [],
            },
          },
        },
      });

      createComponent({ groupsHandler: emptyGroupsHandler });
      jest.advanceTimersByTime(DEBOUNCE_DELAY);
      await waitForPromises();
    });

    it('renders only projects list', () => {
      expect(findDashboardItemsLists()).toHaveLength(1);
      expect(findDashboardItemsLists().at(0).props('groupName')).toBe("Projects I'm a member of");
    });

    it('shows correct status text for screen readers', () => {
      const statusElement = findStatusElement();
      expect(statusElement.text()).toBe('Search found 0 groups and 1 projects');
    });
  });

  describe('when only groups have results', () => {
    beforeEach(async () => {
      const emptyProjectsHandler = jest.fn().mockResolvedValue({
        data: {
          projects: {
            nodes: [],
          },
        },
      });

      createComponent({ projectsHandler: emptyProjectsHandler });
      jest.advanceTimersByTime(DEBOUNCE_DELAY);
      await waitForPromises();
    });

    it('renders only groups list', () => {
      expect(findDashboardItemsLists()).toHaveLength(1);
      expect(findDashboardItemsLists().at(0).props('groupName')).toBe("Groups I'm a member of");
    });

    it('shows correct status text for screen readers', () => {
      const statusElement = findStatusElement();
      expect(statusElement.text()).toBe('Search found 1 groups and 0 projects');
    });
  });

  describe('when queries return null data', () => {
    beforeEach(async () => {
      const nullProjectsHandler = jest.fn().mockResolvedValue({
        data: {
          projects: null,
        },
      });

      const nullGroupsHandler = jest.fn().mockResolvedValue({
        data: {
          currentUser: null,
        },
      });

      createComponent({
        projectsHandler: nullProjectsHandler,
        groupsHandler: nullGroupsHandler,
      });
      jest.advanceTimersByTime(DEBOUNCE_DELAY);
      await waitForPromises();
    });

    it('shows no results message', () => {
      expect(findNoResultsMessage().exists()).toBe(true);
    });
  });

  describe('query variables', () => {
    it('passes search term to both queries', async () => {
      createComponent({ searchTerm: 'my search' });
      jest.advanceTimersByTime(DEBOUNCE_DELAY);
      await waitForPromises();

      expect(projectsQueryHandler).toHaveBeenCalledWith({ search: 'my search' });
      expect(groupsQueryHandler).toHaveBeenCalledWith({ search: 'my search' });
    });
  });
});
