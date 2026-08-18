import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import { GlSprintf } from '@gitlab/ui';
import { mockTracking } from 'helpers/tracking_helper';
import DashboardsList from 'ee/analytics/analytics_dashboards/components/dashboards_list.vue';
import DashboardListItem from 'ee/analytics/analytics_dashboards/components/list/dashboard_list_item.vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { InternalEvents } from '~/tracking';
import { createAlert } from '~/alert';
import PageHeading from '~/vue_shared/components/page_heading.vue';
import ResourceListsLoadingStateList from '~/vue_shared/components/resource_lists/loading_state_list.vue';
import getAllCustomizableDashboardsQuery from 'ee/analytics/analytics_dashboards/graphql/queries/get_all_customizable_dashboards.query.graphql';
import getCustomizableDashboardQuery from 'ee/analytics/analytics_dashboards/graphql/queries/get_customizable_dashboard.query.graphql';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import {
  TEST_COLLECTOR_HOST,
  TEST_DASHBOARD_GRAPHQL_EMPTY_SUCCESS_RESPONSE,
  TEST_CUSTOM_GROUP_VSD_DASHBOARD_GRAPHQL_SUCCESS_RESPONSE,
  TEST_CUSTOM_DASHBOARDS_PROJECT,
  TEST_ALL_DASHBOARDS_GRAPHQL_SUCCESS_RESPONSE,
} from '../mock_data';

const mockAlertDismiss = jest.fn();
jest.mock('~/alert', () => ({
  createAlert: jest.fn().mockImplementation(() => ({
    dismiss: mockAlertDismiss,
  })),
}));

jest.mock('~/analytics/shared/utils', () => ({
  ...jest.requireActual('~/analytics/shared/utils'),
  isEmptyPanelData: jest.fn(),
}));

Vue.use(VueApollo);

describe('DashboardsList', () => {
  /** @type {import('helpers/vue_test_utils_helper').ExtendedWrapper} */
  let wrapper;
  let trackingSpy;

  const findListItems = () => wrapper.findAllComponents(DashboardListItem);
  const findLoadingStateList = () => wrapper.findComponent(ResourceListsLoadingStateList);
  const findPageTitle = () => wrapper.findByTestId('page-heading');
  const findPageDescription = () => wrapper.findByTestId('page-heading-description');
  const findHelpLink = () => wrapper.findByTestId('help-link');

  const $router = {
    push: jest.fn(),
  };
  const showToastMock = jest.fn();
  const $toast = {
    show: showToastMock,
  };

  let mockAnalyticsDashboardsHandler = jest.fn();
  const mockAnalyticsDashboardDetailsHandler = jest.fn();

  const createWrapper = (provided = {}) => {
    trackingSpy = mockTracking(undefined, window.document, jest.spyOn);

    const mockApollo = createMockApollo([
      [getAllCustomizableDashboardsQuery, mockAnalyticsDashboardsHandler],
      [getCustomizableDashboardQuery, mockAnalyticsDashboardDetailsHandler],
    ]);

    wrapper = shallowMountExtended(DashboardsList, {
      apolloProvider: mockApollo,
      stubs: {
        RouterLink: true,
        PageHeading,
        GlSprintf,
      },
      mocks: {
        $router,
        $toast,
      },
      provide: {
        isProject: true,
        isGroup: false,
        collectorHost: TEST_COLLECTOR_HOST,
        namespaceFullPath: TEST_CUSTOM_DASHBOARDS_PROJECT.fullPath,
        ...provided,
      },
    });
  };

  afterEach(() => {
    mockAnalyticsDashboardsHandler.mockReset();
    mockAnalyticsDashboardDetailsHandler.mockReset();
  });

  describe('by default', () => {
    beforeEach(() => {
      createWrapper();
    });

    it('should render the page title', () => {
      expect(findPageTitle().text()).toBe('Analytics dashboards');
    });

    it('should render the default description with link', () => {
      expect(findPageDescription().text()).toBe(
        'Learn more about managing and interacting with analytics dashboards.',
      );
      expect(findHelpLink().text()).toBe('Learn more');
    });

    it('does not render any custom dashboards', () => {
      expect(findListItems()).toHaveLength(0);
    });

    it('should track the dashboard list has been viewed', () => {
      expect(trackingSpy).toHaveBeenCalledWith(
        undefined,
        'user_viewed_dashboard_list',
        expect.any(Object),
      );
    });

    it('fetches the list of dashboards', () => {
      expect(mockAnalyticsDashboardsHandler).toHaveBeenCalledWith({
        fullPath: TEST_CUSTOM_DASHBOARDS_PROJECT.fullPath,
      });
    });

    it('renders a loading state', () => {
      expect(findLoadingStateList().exists()).toBe(true);
    });
  });

  describe('for groups', () => {
    describe('with successful dashboards query', () => {
      beforeEach(() => {
        mockAnalyticsDashboardsHandler = jest
          .fn()
          .mockResolvedValue(TEST_CUSTOM_GROUP_VSD_DASHBOARD_GRAPHQL_SUCCESS_RESPONSE);

        createWrapper({ isProject: false, isGroup: true });

        return waitForPromises();
      });

      it('should render the Value streams dashboards link', () => {
        expect(findListItems()).toHaveLength(1);

        const dashboardAttributes = findListItems().at(0).props('dashboard');

        expect(dashboardAttributes).toMatchObject({
          slug: 'value_streams_dashboard',
          title: 'Value Streams Dashboard',
        });
      });
    });
  });

  describe('when the list of dashboards have been fetched', () => {
    const setupWithResponse = (mockResponseVal) => {
      mockAnalyticsDashboardsHandler = jest.fn().mockResolvedValue(mockResponseVal);

      createWrapper();

      return waitForPromises();
    };

    describe('and there are dashboards', () => {
      beforeEach(() => {
        return setupWithResponse(TEST_ALL_DASHBOARDS_GRAPHQL_SUCCESS_RESPONSE);
      });

      it('does not render a loading state', () => {
        expect(findLoadingStateList().exists()).toBe(false);
      });

      it('renders a list item for each custom dashboard', () => {
        const expectedDashboards =
          TEST_ALL_DASHBOARDS_GRAPHQL_SUCCESS_RESPONSE.data?.project?.customizableDashboards?.nodes;

        expect(findListItems()).toHaveLength(expectedDashboards.length);

        expectedDashboards.forEach(async (dashboard, idx) => {
          const dashboardItem = findListItems().at(idx);
          expect(dashboardItem.props('dashboard')).toEqual(dashboard);
          expect(dashboardItem.attributes()['data-event-tracking']).toBe('user_visited_dashboard');

          InternalEvents.bindInternalEventDocument(dashboardItem.element);
          await dashboardItem.trigger('click');
          await nextTick();

          expect(trackingSpy).toHaveBeenCalledWith(
            undefined,
            'user_visited_dashboard',
            expect.any(Object),
          );
        });
      });
    });

    describe('and the response is empty', () => {
      beforeEach(() => {
        return setupWithResponse(TEST_DASHBOARD_GRAPHQL_EMPTY_SUCCESS_RESPONSE);
      });

      it('does not render a loading state', () => {
        expect(findLoadingStateList().exists()).toBe(false);
      });

      it('does not render any list items', () => {
        expect(findListItems()).toHaveLength(0);
      });
    });
  });

  describe('when an error occurred while fetching the list of dashboards', () => {
    const message = 'failed';
    const error = new Error(message);

    beforeEach(() => {
      mockAnalyticsDashboardsHandler = jest.fn().mockRejectedValue(error);

      createWrapper();

      return waitForPromises();
    });

    it('creates an alert for the error', () => {
      expect(createAlert).toHaveBeenCalledWith({
        captureError: true,
        message,
        error,
      });
    });
  });
});
