import {
  GlSkeletonLoader,
  GlEmptyState,
  GlSprintf,
  GlLink,
  GlDashboardLayout,
  GlExperimentBadge,
} from '@gitlab/ui';
import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { createAlert } from '~/alert';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import waitForPromises from 'helpers/wait_for_promises';
import getCustomizableDashboardQuery from 'ee/analytics/analytics_dashboards/graphql/queries/get_customizable_dashboard.query.graphql';
import AnalyticsDashboard from 'ee/analytics/analytics_dashboards/components/analytics_dashboard.vue';
import AnalyticsDashboardPanel from '~/analytics/shared/components/analytics_dashboard_panel.vue';
import UsageOverviewBackgroundAggregationWarning from 'ee/analytics/dashboards/components/usage_overview_background_aggregation_warning.vue';
import {
  DATE_RANGE_OPTION_TODAY,
  DATE_RANGE_OPTION_CUSTOM,
  DATE_RANGE_OPTION_LAST_7_DAYS,
} from 'ee/analytics/analytics_dashboards/components/filters/constants';
import {
  buildDefaultDashboardFilters,
  filtersToQueryParams,
} from 'ee/analytics/analytics_dashboards/components/filters/utils';
import AnonUsersFilter from 'ee/analytics/analytics_dashboards/components/filters/anon_users_filter.vue';
import DateRangeFilter from '~/explore/analytics_dashboards/components/date_range_filter.vue';
import ProjectsFilter from '~/explore/analytics_dashboards/components/projects_filter.vue';
import createMockApollo from 'helpers/mock_apollo_helper';
import {
  EVENT_LABEL_EXCLUDE_ANONYMISED_USERS,
  EVENT_LABEL_VIEWED_CUSTOM_DASHBOARD,
  EVENT_LABEL_VIEWED_BUILTIN_DASHBOARD,
  EVENT_LABEL_VIEWED_DASHBOARD,
} from 'ee/analytics/analytics_dashboards/constants';
import { stubComponent } from 'helpers/stub_component';
import { useMockInternalEventsTracking } from 'helpers/tracking_internal_events_helper';
import UrlSync, {
  HISTORY_REPLACE_UPDATE_METHOD,
  URL_SET_PARAMS_STRATEGY,
} from '~/vue_shared/components/url_sync.vue';
import FilteredSearchFilter from 'ee/analytics/analytics_dashboards/components/filters/filtered_search_filter.vue';
import {
  TEST_CUSTOM_DASHBOARDS_GROUP,
  TEST_ROUTER_BACK_HREF,
  TEST_DASHBOARD_GRAPHQL_404_RESPONSE,
  TEST_CUSTOM_VSD_DASHBOARD_GRAPHQL_SUCCESS_RESPONSE,
  TEST_CUSTOM_GROUP_VSD_DASHBOARD_GRAPHQL_SUCCESS_RESPONSE,
  TEST_AI_IMPACT_DASHBOARD_GRAPHQL_SUCCESS_RESPONSE,
  createDashboardGraphqlSuccessResponse,
  createGroupDashboardGraphqlSuccessResponse,
  TEST_INVALID_CUSTOM_DASHBOARD_GRAPHQL_SUCCESS_RESPONSE,
  mockInvalidDashboardErrors,
  TEST_DASHBOARD_WITH_USAGE_OVERVIEW_GRAPHQL_SUCCESS_RESPONSE,
  TEST_DASHBOARD_WITH_USAGE_COUNT_GRAPHQL_SUCCESS_RESPONSE,
  TEST_CUSTOM_DASHBOARDS_PROJECT,
  TEST_DASHBOARD_GRAPHQL_SUCCESS_RESPONSE,
  getGraphQLDashboardWithPanels,
  mockDateRangeFilterChangePayload,
  mockFilteredSearchChangePayload,
  TEST_EMPTY_DASHBOARD_SVG_PATH,
} from '../mock_data';

jest.mock('~/sentry/sentry_browser_wrapper');

const mockAlertDismiss = jest.fn();
jest.mock('~/alert', () => ({
  createAlert: jest.fn().mockImplementation(() => ({
    dismiss: mockAlertDismiss,
  })),
}));

Vue.use(VueApollo);

describe('AnalyticsDashboard', () => {
  /** @type {import('helpers/vue_test_utils_helper').ExtendedWrapper} */
  let wrapper;

  const { bindInternalEventDocument } = useMockInternalEventsTracking();

  const findDashboard = () => wrapper.findComponent(GlDashboardLayout);
  const findAllPanels = () => wrapper.findAllComponents(AnalyticsDashboardPanel);
  const findPanelByTitle = (title) =>
    findAllPanels().wrappers.find((w) => w.props('title') === title);
  const findLoader = () => wrapper.findComponent(GlSkeletonLoader);
  const findEmptyState = () => wrapper.findComponent(GlEmptyState);
  const findInvalidDashboardAlert = () =>
    wrapper.findComponentByTestId('analytics-dashboard-invalid-config-alert');
  const findUsageOverviewAggregationWarning = () =>
    wrapper.findComponent(UsageOverviewBackgroundAggregationWarning);
  const findCustomTitle = () => wrapper.findByTestId('custom-title');
  const findCustomDescription = () => wrapper.findByTestId('custom-description');
  const findCustomDescriptionLink = () => wrapper.findByTestId('custom-description-link');
  const findExperimentBadge = () => wrapper.findComponent(GlExperimentBadge);
  const findAnonUsersFilter = () => wrapper.findComponent(AnonUsersFilter);
  const findDateRangeFilter = () => wrapper.findComponent(DateRangeFilter);
  const findProjectsFilter = () => wrapper.findComponent(ProjectsFilter);
  const findFilteredSearchFilter = () => wrapper.findComponent(FilteredSearchFilter);
  const findUrlSync = () => wrapper.findComponent(UrlSync);

  const getFirstParsedDashboard = (dashboards) => {
    const firstDashboard = dashboards.data.project.customizableDashboards.nodes[0];

    const panels = firstDashboard.panels?.nodes || [];

    return {
      ...firstDashboard,
      panels,
    };
  };

  let mockAnalyticsDashboardsHandler = jest.fn();

  const mockDashboardResponse = (response) => {
    mockAnalyticsDashboardsHandler = jest.fn().mockResolvedValue(response);
  };

  afterEach(() => {
    mockAnalyticsDashboardsHandler = jest.fn();
  });

  const breadcrumbState = { updateName: jest.fn() };

  const mockNamespace = {
    namespaceFullPath: TEST_CUSTOM_DASHBOARDS_PROJECT.fullPath,
  };

  const createWrapper = ({ props = {}, routeSlug = '', provide = {} } = {}) => {
    const mocks = {
      $route: {
        params: {
          slug: routeSlug,
        },
      },
      $router: {
        resolve: () => ({ href: TEST_ROUTER_BACK_HREF }),
      },
    };

    const mockApollo = createMockApollo([
      [getCustomizableDashboardQuery, mockAnalyticsDashboardsHandler],
    ]);

    wrapper = shallowMountExtended(AnalyticsDashboard, {
      apolloProvider: mockApollo,
      propsData: {
        ...props,
      },
      stubs: {
        GlSprintf,
        GlLink,
        AnonUsersFilter,
        DateRangeFilter,
        FilteredSearchFilter,
        ProjectsFilter,
        GlDashboardLayout: stubComponent(GlDashboardLayout, {
          template: `<div>
            <slot name="alert"></slot>
            <slot name="title"></slot>
            <slot name="description"></slot>
            <slot name="filters"></slot>
            <template v-for="panel in config.panels">
              <slot name="panel" v-bind="{ panel }"></slot>
            </template>
          </div>`,
        }),
      },
      mocks,
      provide: {
        ...mockNamespace,
        dashboardEmptyStateIllustrationPath: TEST_EMPTY_DASHBOARD_SVG_PATH,
        breadcrumbState,
        isGroup: false,
        isProject: true,
        overviewCountsAggregationEnabled: true,
        ...provide,
      },
    });
  };

  const setupDashboard = (dashboardResponse, slug = '', provide = {}) => {
    mockDashboardResponse(dashboardResponse);
    createWrapper({
      routeSlug: slug,
      provide,
    });

    return waitForPromises();
  };

  describe('container classes updates', () => {
    let wrapperLimited;

    beforeEach(() => {
      wrapperLimited = document.createElement('div');
      wrapperLimited.classList.add('container-fluid', 'container-limited');
      document.body.appendChild(wrapperLimited);

      createWrapper();
    });

    afterEach(() => {
      document.body.removeChild(wrapperLimited);
    });

    it('body container', () => {
      expect(document.querySelectorAll('.container-fluid.not-container-limited')).toHaveLength(1);
    });

    it('body container after destroy', () => {
      wrapper.destroy();

      expect(document.querySelectorAll('.container-fluid.not-container-limited')).toHaveLength(0);
      expect(document.querySelectorAll('.container-fluid.container-limited')).toHaveLength(1);
    });
  });

  describe('when mounted', () => {
    beforeEach(() => {
      mockDashboardResponse(TEST_DASHBOARD_GRAPHQL_SUCCESS_RESPONSE);
    });

    it('should render with mock dashboard', async () => {
      createWrapper();

      await waitForPromises();

      expect(mockAnalyticsDashboardsHandler).toHaveBeenCalledWith({
        fullPath: TEST_CUSTOM_DASHBOARDS_PROJECT.fullPath,
        slug: '',
      });

      expect(findDashboard().props()).toMatchObject({
        config: getFirstParsedDashboard(TEST_DASHBOARD_GRAPHQL_SUCCESS_RESPONSE),
      });

      expect(breadcrumbState.updateName).toHaveBeenCalledWith('Audience');
    });

    it('should render the loading icon while fetching data', async () => {
      createWrapper({
        routeSlug: 'audience',
      });

      expect(findLoader().exists()).toBe(true);

      await waitForPromises();

      expect(findLoader().exists()).toBe(false);
    });

    it('should render dashboard by slug', async () => {
      createWrapper({
        routeSlug: 'audience',
      });

      await waitForPromises();

      expect(mockAnalyticsDashboardsHandler).toHaveBeenCalledWith({
        fullPath: TEST_CUSTOM_DASHBOARDS_PROJECT.fullPath,
        slug: 'audience',
      });

      expect(breadcrumbState.updateName).toHaveBeenCalledWith('Audience');

      expect(findDashboard().exists()).toBe(true);
    });

    it('should not render invalid dashboard alert', async () => {
      createWrapper();

      await waitForPromises();

      expect(findInvalidDashboardAlert().exists()).toBe(false);
    });

    it('should not render the usage overview aggregation warning', async () => {
      createWrapper();

      await waitForPromises();

      expect(findUsageOverviewAggregationWarning().exists()).toBe(false);
    });

    it('should use the default cell height for the grid', async () => {
      createWrapper();

      await waitForPromises();

      expect(findDashboard().props()).toMatchObject({
        cellHeight: 137,
        minCellHeight: 1,
      });
    });

    it('should add unique panel ids to each panel', async () => {
      createWrapper();

      await waitForPromises();

      expect(findDashboard().props().config.panels).toEqual(
        expect.arrayContaining([
          expect.objectContaining({
            id: expect.stringContaining('panel-'),
          }),
        ]),
      );
    });

    it('renders an analytics dashboard panel component for each panel', async () => {
      createWrapper();

      await waitForPromises();

      const { panels } = getFirstParsedDashboard(TEST_DASHBOARD_GRAPHQL_SUCCESS_RESPONSE);

      expect(findAllPanels()).toHaveLength(panels.length);

      panels.forEach((panel) => {
        expect(findPanelByTitle(panel.title).props()).toMatchObject({
          title: panel.title,
          titleIcon: panel.titleIcon,
          visualization: panel.visualization,
          queryOverrides: panel.queryOverrides || undefined,
          filters: buildDefaultDashboardFilters(''),
          tooltip: panel.tooltip || undefined,
          views: panel.views,
        });
      });
    });

    it('should not render a custom title by default', async () => {
      createWrapper();

      await waitForPromises();

      expect(findCustomTitle().exists()).toBe(false);
    });

    it('should not render a badge by default', async () => {
      createWrapper();

      await waitForPromises();

      expect(findExperimentBadge().exists()).toBe(false);
    });

    it('should not render a custom description by default', async () => {
      createWrapper();

      await waitForPromises();

      expect(findCustomDescription().exists()).toBe(false);
      expect(findCustomDescriptionLink().exists()).toBe(false);
    });

    it('should not render filters by default', async () => {
      createWrapper();

      await waitForPromises();

      expect(findUrlSync().exists()).toBe(false);
      expect(findAnonUsersFilter().exists()).toBe(false);
      expect(findDateRangeFilter().exists()).toBe(false);
      expect(findFilteredSearchFilter().exists()).toBe(false);
    });
  });

  describe('when dashboard fails to load', () => {
    let error = new Error();

    beforeEach(() => {
      mockAnalyticsDashboardsHandler = jest.fn().mockRejectedValue(error);

      createWrapper();
      return waitForPromises();
    });

    it('does not render the dashboard or loader', () => {
      expect(findDashboard().exists()).toBe(false);
      expect(findLoader().exists()).toBe(false);
      expect(breadcrumbState.updateName).toHaveBeenCalledWith('');
    });

    it('creates an alert', () => {
      expect(createAlert).toHaveBeenCalledWith({
        message: expect.stringContaining('ruh roh some error. Refresh the page to try again.'),
        messageLinks: {
          link: '/help/user/analytics/analytics_dashboards',
        },
        captureError: true,
        error,
        title: 'Failed to load dashboard',
      });
    });

    describe('with a specified error message', () => {
      error = new Error('ruh roh some error');

      beforeEach(() => {
        mockAnalyticsDashboardsHandler = jest.fn().mockRejectedValue(error);

        createWrapper();
        return waitForPromises();
      });

      it('creates an alert with the error message and a troubleshooting link', () => {
        expect(createAlert).toHaveBeenCalledWith({
          message: expect.stringContaining('ruh roh some error. Refresh the page to try again.'),
          messageLinks: {
            link: '/help/user/analytics/analytics_dashboards',
          },
          captureError: true,
          error,
          title: 'Failed to load dashboard',
        });
      });
    });
  });

  describe('when a custom dashboard cannot be found', () => {
    beforeEach(() => {
      mockDashboardResponse(TEST_DASHBOARD_GRAPHQL_404_RESPONSE);

      createWrapper();

      return waitForPromises();
    });

    it('does not render the dashboard or loader', () => {
      expect(findDashboard().exists()).toBe(false);
      expect(findLoader().exists()).toBe(false);
      expect(breadcrumbState.updateName).toHaveBeenCalledWith('');
    });

    it('renders the empty state', () => {
      expect(findEmptyState().props()).toMatchObject({
        svgPath: TEST_EMPTY_DASHBOARD_SVG_PATH,
        title: 'Dashboard not found',
        description: 'No dashboard matches the specified URL path.',
        primaryButtonText: 'View available dashboards',
        primaryButtonLink: TEST_ROUTER_BACK_HREF,
      });
    });
  });

  describe("when the dashboard's configuration is invalid", () => {
    beforeEach(() => {
      mockDashboardResponse(TEST_INVALID_CUSTOM_DASHBOARD_GRAPHQL_SUCCESS_RESPONSE);

      createWrapper();

      return waitForPromises();
    });

    it('does not render the loader', () => {
      expect(findLoader().exists()).toBe(false);
    });

    it('renders the dashboard', () => {
      expect(findDashboard().exists()).toBe(true);
    });

    it('renders an alert with error messages', () => {
      expect(findInvalidDashboardAlert().props()).toMatchObject({
        title: 'Invalid dashboard configuration',
        primaryButtonText: 'Learn more',
        primaryButtonLink: '/help/user/analytics/analytics_dashboards',
        dismissible: false,
      });

      mockInvalidDashboardErrors.forEach((error) =>
        expect(findInvalidDashboardAlert().text()).toContain(error),
      );
    });
  });

  describe.each`
    userDefined | event                                   | title
    ${false}    | ${EVENT_LABEL_VIEWED_BUILTIN_DASHBOARD} | ${'Audience'}
    ${true}     | ${EVENT_LABEL_VIEWED_CUSTOM_DASHBOARD}  | ${'My custom dashboard'}
  `('when a dashboard is userDefined=$userDefined is viewed', ({ userDefined, event, title }) => {
    beforeEach(() => {
      setupDashboard(
        createDashboardGraphqlSuccessResponse(
          getGraphQLDashboardWithPanels({ userDefined, title }),
        ),
      );

      return waitForPromises();
    });

    it(`tracks the "${event}" event`, () => {
      const { trackEventSpy } = bindInternalEventDocument(wrapper.element);

      expect(trackEventSpy).toHaveBeenCalledWith(event, { label: title }, undefined);
    });

    it(`tracks the "${EVENT_LABEL_VIEWED_DASHBOARD}" event`, () => {
      const { trackEventSpy } = bindInternalEventDocument(wrapper.element);

      expect(trackEventSpy).toHaveBeenCalledWith(
        EVENT_LABEL_VIEWED_DASHBOARD,
        { label: title },
        undefined,
      );
    });

    it('tracks exactly two events', () => {
      const { trackEventSpy } = bindInternalEventDocument(wrapper.element);

      expect(trackEventSpy).toHaveBeenCalledTimes(2);
    });
  });

  describe('status badge', () => {
    describe('with a built-in dashboard', () => {
      it('renders the custom title with badge', async () => {
        await setupDashboard(
          createDashboardGraphqlSuccessResponse(
            getGraphQLDashboardWithPanels({ status: 'beta', title: 'Beta dashboard' }),
          ),
          'test-beta-dashboard',
        );

        expect(findCustomTitle().text()).toContain('Beta dashboard');
        expect(findExperimentBadge().props('type')).toBe('beta');
      });
    });

    describe('with a user defined dashboard', () => {
      it('does not render a status badge', async () => {
        await setupDashboard(
          createDashboardGraphqlSuccessResponse(
            getGraphQLDashboardWithPanels({
              status: 'beta',
              title: 'Beta dashboard',
              userDefined: true,
            }),
          ),
          'test-beta-dashboard',
        );

        expect(findExperimentBadge().exists()).toBe(false);
      });
    });
  });

  describe('filters', () => {
    const defaultFilters = buildDefaultDashboardFilters('');
    let trackEventSpy;

    const setupGroupDashboardWithFilters = (filters) => {
      setupDashboard(
        createGroupDashboardGraphqlSuccessResponse(getGraphQLDashboardWithPanels({ filters })),
        'test-dashboard-with-filters',
      );

      createWrapper({
        provide: {
          namespaceFullPath: TEST_CUSTOM_DASHBOARDS_GROUP.fullPath,
          isGroup: true,
          isProject: false,
        },
      });
      return waitForPromises();
    };

    const setupDashboardWithFilters = (filters) => {
      setupDashboard(
        createDashboardGraphqlSuccessResponse(getGraphQLDashboardWithPanels({ filters })),
        'test-dashboard-with-filters',
      );
      createWrapper({});
      return waitForPromises();
    };

    describe('anonymous user filter', () => {
      beforeEach(async () => {
        await setupDashboardWithFilters({ excludeAnonymousUsers: { enabled: true } });
      });

      it('synchronizes the filters with the URL', () => {
        expect(findUrlSync().props()).toMatchObject({
          historyUpdateMethod: HISTORY_REPLACE_UPDATE_METHOD,
          urlParamsUpdateStrategy: URL_SET_PARAMS_STRATEGY,
          query: filtersToQueryParams(defaultFilters),
        });
      });

      it('sets the default filter on the anon users filter component', () => {
        expect(findAnonUsersFilter().props('value')).toBe(defaultFilters.filterAnonUsers);
      });

      it('sets the panel filter', () => {
        expect(findAllPanels().at(0).props('filters')).toMatchObject({
          filterAnonUsers: defaultFilters.filterAnonUsers,
        });
      });

      describe('when filter changes', () => {
        beforeEach(() => {
          trackEventSpy = bindInternalEventDocument(wrapper.element).trackEventSpy;
        });

        beforeEach(async () => {
          findAnonUsersFilter().vm.$emit('change', true);
          await waitForPromises();
        });

        it('updates the filter on the anon users filter component', () => {
          expect(findAnonUsersFilter().props('value')).toBe(true);
        });

        it('updates the panel filter', () => {
          expect(findAllPanels().at(0).props('filters')).toMatchObject({
            filterAnonUsers: true,
          });
        });
        it(`tracks the "${EVENT_LABEL_EXCLUDE_ANONYMISED_USERS}" event when excluding anon users`, () => {
          expect(trackEventSpy).toHaveBeenCalledWith(
            EVENT_LABEL_EXCLUDE_ANONYMISED_USERS,
            {},
            undefined,
          );
        });

        it(`does not track "${EVENT_LABEL_EXCLUDE_ANONYMISED_USERS}" event including anon users`, async () => {
          trackEventSpy.mockClear();

          await findAnonUsersFilter().vm.$emit('change', false);

          expect(trackEventSpy).not.toHaveBeenCalled();
        });
      });
    });

    describe('projects filter', () => {
      const findDropdownGroupNamespace = () => findProjectsFilter().props('groupNamespace');

      describe('when dashboard is group-level', () => {
        beforeEach(async () => {
          await setupGroupDashboardWithFilters({ projects: { enabled: true } });
        });

        it('renders the filter', () => {
          expect(findProjectsFilter().exists()).toBe(true);
          expect(findProjectsFilter().props().multiSelect).toBe(false);
          expect(findDropdownGroupNamespace()).toBe(TEST_CUSTOM_DASHBOARDS_GROUP.fullPath);
        });

        it('enables multiSelect based on the dashboard config', async () => {
          await setupGroupDashboardWithFilters({ projects: { enabled: true, multiSelect: true } });
          expect(findProjectsFilter().exists()).toBe(true);
          expect(findProjectsFilter().props().multiSelect).toBe(true);
        });

        it('synchronizes the filters with the URL', () => {
          expect(findUrlSync().props()).toMatchObject({
            historyUpdateMethod: HISTORY_REPLACE_UPDATE_METHOD,
            urlParamsUpdateStrategy: URL_SET_PARAMS_STRATEGY,
            query: filtersToQueryParams(defaultFilters),
          });
        });

        describe('on project selection', () => {
          const selectedProject = {
            id: 'gid://test-project',
            name: 'test-project',
            fullPath: 'test/project',
          };

          beforeEach(async () => {
            await findProjectsFilter().vm.$emit('project-selected', [selectedProject]);
          });

          it('synchronizes the filters with the URL', () => {
            expect(findUrlSync().props()).toMatchObject({
              historyUpdateMethod: HISTORY_REPLACE_UPDATE_METHOD,
              urlParamsUpdateStrategy: URL_SET_PARAMS_STRATEGY,
              query: filtersToQueryParams({ projects: [selectedProject.fullPath] }),
            });
          });

          it('updates the slot filters', () => {
            expect(findAllPanels().at(0).props('filters')).toMatchObject({
              projects: [selectedProject.fullPath],
            });
          });
        });
      });

      describe('when dashboard is project-level', () => {
        beforeEach(async () => {
          await setupDashboardWithFilters({ projectSelector: { enabled: true } }, false);
        });
        it('does not render the filter', () => {
          expect(findProjectsFilter().exists()).toBe(false);
        });
      });
    });

    describe('date range filter', () => {
      const defaultDateRangeFilters = buildDefaultDashboardFilters('', {
        dateRange: { enabled: true },
      });

      beforeEach(async () => {
        await setupDashboardWithFilters({ dateRange: { enabled: true } });
      });

      it('synchronizes the filters with the URL', () => {
        expect(findUrlSync().props()).toMatchObject({
          historyUpdateMethod: HISTORY_REPLACE_UPDATE_METHOD,
          urlParamsUpdateStrategy: URL_SET_PARAMS_STRATEGY,
          query: filtersToQueryParams(defaultDateRangeFilters),
        });
      });

      it('shows the date range filter and passes the default options and filters', () => {
        expect(findDateRangeFilter().props()).toMatchObject({
          startDate: defaultDateRangeFilters.startDate,
          endDate: defaultDateRangeFilters.endDate,
          defaultOption: defaultDateRangeFilters.dateRangeOption,
          dateRangeLimit: 0,
        });
      });

      it('sets the date range limit based on config if it exists', async () => {
        await setupDashboardWithFilters({ dateRange: { enabled: true, numberOfDaysLimit: 99 } });
        expect(findDateRangeFilter().props('dateRangeLimit')).toBe(99);
      });

      it('sets the date range options based on config if it exists', async () => {
        await setupDashboardWithFilters({
          dateRange: {
            enabled: true,
            options: [DATE_RANGE_OPTION_TODAY, DATE_RANGE_OPTION_CUSTOM],
          },
        });

        expect(findDateRangeFilter().props('options')).toEqual([
          DATE_RANGE_OPTION_TODAY,
          DATE_RANGE_OPTION_CUSTOM,
        ]);
      });

      it('displays a warning when the defaultOption is not in the list of options', async () => {
        await setupDashboardWithFilters({
          dateRange: {
            enabled: true,
            defaultOption: DATE_RANGE_OPTION_LAST_7_DAYS,
            options: [DATE_RANGE_OPTION_TODAY, DATE_RANGE_OPTION_CUSTOM],
          },
        });

        expect(createAlert).toHaveBeenCalledWith({
          title: 'Date range filter validation',
          message: "Default date range '7d' is not included in the list of dateRange options",
        });
      });

      it('sets the panel filters', () => {
        expect(findAllPanels().at(0).props('filters')).toMatchObject({
          dateRangeOption: defaultDateRangeFilters.dateRangeOption,
          startDate: defaultDateRangeFilters.startDate,
          endDate: defaultDateRangeFilters.endDate,
        });
      });

      describe('when filters change', () => {
        beforeEach(async () => {
          await findDateRangeFilter().vm.$emit('change', mockDateRangeFilterChangePayload);
        });
        it('updates the slot filters', () => {
          expect(findAllPanels().at(0).props('filters')).toMatchObject({
            dateRangeOption: mockDateRangeFilterChangePayload.dateRangeOption,
            startDate: mockDateRangeFilterChangePayload.startDate,
            endDate: mockDateRangeFilterChangePayload.endDate,
          });
        });

        it('synchronizes the updated filters with the URL', () => {
          expect(findUrlSync().props()).toMatchObject({
            historyUpdateMethod: HISTORY_REPLACE_UPDATE_METHOD,
            urlParamsUpdateStrategy: URL_SET_PARAMS_STRATEGY,
            query: filtersToQueryParams(mockDateRangeFilterChangePayload),
          });
        });
      });
    });

    describe('filtered search filter', () => {
      beforeEach(async () => {
        await setupDashboardWithFilters({ filteredSearch: { enabled: true } });
      });

      it('synchronizes the filters with the URL', () => {
        expect(findUrlSync().props()).toMatchObject({
          historyUpdateMethod: HISTORY_REPLACE_UPDATE_METHOD,
          urlParamsUpdateStrategy: URL_SET_PARAMS_STRATEGY,
          query: filtersToQueryParams(defaultFilters),
        });
      });

      it('shows the filtered search filter', () => {
        expect(findFilteredSearchFilter().props()).toMatchObject({
          initialFilterValue: defaultFilters.searchFilters,
        });
      });

      it('sets the filtered search options when they are present', async () => {
        const mockFilteredSearchOptions = [{ token: 'assignee', unique: true }];

        await setupDashboardWithFilters({
          filteredSearch: {
            enabled: true,
            options: mockFilteredSearchOptions,
          },
        });

        expect(findFilteredSearchFilter().props('options')).toEqual(mockFilteredSearchOptions);
      });

      describe('when filters change', () => {
        beforeEach(async () => {
          await findFilteredSearchFilter().vm.$emit('change', mockFilteredSearchChangePayload);
        });

        it('updates the slot filters', () => {
          expect(findAllPanels().at(0).props('filters')).toMatchObject({
            searchFilters: mockFilteredSearchChangePayload,
          });
        });

        it('synchronizes the updated filters with the URL', () => {
          expect(findUrlSync().props()).toMatchObject({
            historyUpdateMethod: HISTORY_REPLACE_UPDATE_METHOD,
            urlParamsUpdateStrategy: URL_SET_PARAMS_STRATEGY,
            query: filtersToQueryParams({ searchFilters: mockFilteredSearchChangePayload }),
          });
        });

        it(`updates the search filter's initial value with the updated filters`, () => {
          expect(findFilteredSearchFilter().props('initialFilterValue')).toEqual(
            mockFilteredSearchChangePayload,
          );
        });
      });
    });
  });

  describe('with an AI impact dashboard', () => {
    beforeEach(() => {
      mockDashboardResponse(TEST_AI_IMPACT_DASHBOARD_GRAPHQL_SUCCESS_RESPONSE);

      createWrapper();
      return waitForPromises();
    });

    it('renders the dashboard correctly', () => {
      expect(findDashboard().props()).toMatchObject({
        config: {
          ...getFirstParsedDashboard(TEST_DASHBOARD_GRAPHQL_SUCCESS_RESPONSE),
          title: 'GitLab Duo and SDLC trends',
          slug: 'duo_and_sdlc_trends',
        },
      });
    });

    it('renders a custom description with links', () => {
      const description = findCustomDescription();
      expect(description.text()).toContain('Understand your audience');
      const linkWrapper = findCustomDescriptionLink();
      const links = linkWrapper.findAllComponents(GlLink);

      expect(linkWrapper.text()).toBe('Learn more about Duo and SDLC trends and Duo seats.');

      const expectedLinks = [
        {
          text: 'Duo and SDLC trends',
          href: '/help/user/analytics/duo_and_sdlc_trends',
        },
        {
          text: 'Duo seats',
          href: '/help/subscriptions/subscription-add-ons',
        },
      ];

      expectedLinks.forEach((expected, index) => {
        const link = links.at(index);
        expect(link.text()).toBe(expected.text);
        expect(link.attributes('href')).toBe(expected.href);
      });
    });

    it('does not render filters', () => {
      expect(findAnonUsersFilter().exists()).toBe(false);
      expect(findDateRangeFilter().exists()).toBe(false);
      expect(findProjectsFilter().exists()).toBe(false);
      expect(findFilteredSearchFilter().exists()).toBe(false);
      expect(findUrlSync().exists()).toBe(false);
    });
  });

  describe('with a value stream dashboard', () => {
    beforeEach(async () => {
      mockDashboardResponse(TEST_CUSTOM_VSD_DASHBOARD_GRAPHQL_SUCCESS_RESPONSE);

      createWrapper();
      await waitForPromises();
    });

    it('renders the dashboard correctly', () => {
      expect(findDashboard().props()).toMatchObject({
        config: {
          ...getFirstParsedDashboard(TEST_DASHBOARD_GRAPHQL_SUCCESS_RESPONSE),
          title: 'Value Streams Dashboard',
          slug: 'value_streams_dashboard',
        },
      });
    });

    it('renders a custom description with links', () => {
      const description = findCustomDescription();
      expect(description.text()).toContain('Understand your audience');
      const linkWrapper = findCustomDescriptionLink();

      expect(linkWrapper.text()).toBe('Learn more.');
      expect(linkWrapper.findComponent(GlLink).attributes('href')).toBe(
        '/help/user/analytics/value_streams_dashboard',
      );
    });

    it('does not render filters', () => {
      expect(findAnonUsersFilter().exists()).toBe(false);
      expect(findDateRangeFilter().exists()).toBe(false);
      expect(findFilteredSearchFilter().exists()).toBe(false);
      expect(findUrlSync().exists()).toBe(false);
    });
  });

  describe('with a group namespace', () => {
    beforeEach(async () => {
      mockDashboardResponse(TEST_CUSTOM_GROUP_VSD_DASHBOARD_GRAPHQL_SUCCESS_RESPONSE);

      createWrapper({
        routeSlug: 'value_streams_dashboard',
        provide: {
          namespaceFullPath: TEST_CUSTOM_DASHBOARDS_GROUP.fullPath,
          isGroup: true,
          isProject: false,
        },
      });
      await waitForPromises();
    });

    it('will fetch the group data', () => {
      expect(mockAnalyticsDashboardsHandler).toHaveBeenCalledWith({
        fullPath: TEST_CUSTOM_DASHBOARDS_GROUP.fullPath,
        slug: 'value_streams_dashboard',
      });
    });

    it('will set the dashboard data', async () => {
      mockDashboardResponse(TEST_CUSTOM_GROUP_VSD_DASHBOARD_GRAPHQL_SUCCESS_RESPONSE);

      createWrapper({
        routeSlug: 'value_streams_dashboard',
        provide: {
          namespaceFullPath: TEST_CUSTOM_DASHBOARDS_GROUP.fullPath,
          isGroup: true,
          isProject: false,
        },
      });

      await waitForPromises();

      expect(findDashboard().props()).toMatchObject({
        config: {
          ...getFirstParsedDashboard(TEST_DASHBOARD_GRAPHQL_SUCCESS_RESPONSE),
          title: 'Value Streams Dashboard',
          slug: 'value_streams_dashboard',
          panels: [],
        },
      });
    });
  });

  describe('when usage overview aggregation is not enabled', () => {
    describe.each`
      panelType           | dashboardResponse
      ${'usage overview'} | ${TEST_DASHBOARD_WITH_USAGE_OVERVIEW_GRAPHQL_SUCCESS_RESPONSE}
      ${'usage count'}    | ${TEST_DASHBOARD_WITH_USAGE_COUNT_GRAPHQL_SUCCESS_RESPONSE}
    `('with a $panelType panel', ({ dashboardResponse }) => {
      beforeEach(async () => {
        mockDashboardResponse(dashboardResponse);

        createWrapper({
          provide: {
            overviewCountsAggregationEnabled: false,
          },
        });

        await waitForPromises();
      });

      it('renders the usage overview aggregation warning', () => {
        expect(findUsageOverviewAggregationWarning().exists()).toBe(true);
      });
    });
  });

  describe('when COMPACT gridHeight is used', () => {
    beforeEach(() => {
      setupDashboard(
        createDashboardGraphqlSuccessResponse(
          getGraphQLDashboardWithPanels({ gridHeight: 'COMPACT' }),
        ),
      );

      return waitForPromises();
    });

    it('sets the correct cell height and min cell height for the grid', () => {
      expect(findDashboard().props()).toMatchObject({
        cellHeight: 10,
        minCellHeight: 10,
      });
    });
  });
});
