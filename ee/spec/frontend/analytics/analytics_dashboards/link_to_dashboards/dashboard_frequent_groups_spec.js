import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { DEBOUNCE_DELAY } from '~/vue_shared/components/filtered_search_bar/constants';
import DashboardFrequentGroups from 'ee/analytics/analytics_dashboards/link_to_dashboards/dashboard_frequent_groups.vue';
import DashboardItemsList from 'ee/analytics/analytics_dashboards/link_to_dashboards/dashboard_items_list.vue';
import currentUserFrecentGroupsQueryWithDashboards from 'ee/analytics/analytics_dashboards/link_to_dashboards/graphql/current_user_frecent_groups_with_dashboards.query.graphql';

Vue.use(VueApollo);

describe('DashboardFrequentGroups', () => {
  let wrapper;
  let mockApollo;

  const mockFrecentGroups = [
    {
      id: 'gid://gitlab/Group/1',
      name: 'Group 1',
      namespace: 'namespace / Group 1',
      avatarUrl: '/avatar1.png',
      fullPath: 'namespace/group-1',
      customizableDashboards: {
        nodes: [{ slug: 'duo_and_sdlc_trends' }],
      },
    },
    {
      id: 'gid://gitlab/Group/2',
      name: 'Group 2',
      namespace: 'namespace / Group 2',
      avatarUrl: '/avatar2.png',
      fullPath: 'namespace/group-2',
      customizableDashboards: {
        nodes: [{ slug: 'value_streams_dashboard' }],
      },
    },
    {
      id: 'gid://gitlab/Group/3',
      name: 'Group 3',
      namespace: 'namespace / Group 3',
      avatarUrl: '/avatar3.png',
      fullPath: 'namespace/group-3',
      customizableDashboards: {
        nodes: [{ slug: 'duo_and_sdlc_trends' }],
      },
    },
  ];

  const frecentGroupsQueryHandler = jest.fn().mockResolvedValue({
    data: {
      frecentGroups: mockFrecentGroups,
    },
  });

  const createComponent = ({ queryHandler = frecentGroupsQueryHandler } = {}) => {
    mockApollo = createMockApollo([[currentUserFrecentGroupsQueryWithDashboards, queryHandler]]);

    wrapper = shallowMountExtended(DashboardFrequentGroups, {
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

    it('filters groups to only those with the specified dashboard', () => {
      const items = findDashboardItemsList().props('items');

      expect(items).toHaveLength(2);
      expect(items[0].id).toBe('gid://gitlab/Group/1');
      expect(items[1].id).toBe('gid://gitlab/Group/3');
    });

    it('passes correct props to DashboardItemsList', () => {
      expect(findDashboardItemsList().props()).toMatchObject({
        loading: false,
        emptyStateText: 'Groups you visit often will appear here.',
        groupName: 'Frequently visited groups',
        isGroup: true,
        dashboardName: 'duo_and_sdlc_trends',
      });
    });
  });

  describe('when query returns empty data', () => {
    beforeEach(async () => {
      const emptyQueryHandler = jest.fn().mockResolvedValue({
        data: {
          frecentGroups: [],
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
          frecentGroups: null,
        },
      });
      createComponent({ queryHandler: nullQueryHandler });
      await waitForQuery();
    });

    it('passes empty array to DashboardItemsList', () => {
      expect(findDashboardItemsList().props('items')).toEqual([]);
    });
  });

  describe('when no groups have the specified dashboard', () => {
    beforeEach(async () => {
      const groupsWithoutDashboard = mockFrecentGroups.map((group) => ({
        ...group,
        customizableDashboards: {
          nodes: [{ slug: 'other_dashboard' }],
        },
      }));

      const queryHandler = jest.fn().mockResolvedValue({
        data: {
          frecentGroups: groupsWithoutDashboard,
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
