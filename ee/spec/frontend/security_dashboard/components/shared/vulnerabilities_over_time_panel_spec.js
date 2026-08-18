import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import setWindowLocation from 'helpers/set_window_location_helper';
import ExtendedDashboardPanel from '~/vue_shared/components/customizable_dashboard/extended_dashboard_panel.vue';
import * as panelStateUrlSync from 'ee/security_dashboard/utils/panel_state_url_sync';
import VulnerabilitiesOverTimeChart from 'ee/security_dashboard/components/shared/charts/open_vulnerabilities_over_time.vue';
import VulnerabilitiesOverTimePanel from 'ee/security_dashboard/components/shared/vulnerabilities_over_time_panel.vue';
import PanelGroupBy from 'ee/security_dashboard/components/shared/panel_group_by.vue';
import PanelSeverityFilter from 'ee/security_dashboard/components/shared/panel_severity_filter.vue';
import OverTimePeriodSelector from 'ee/security_dashboard/components/shared/over_time_period_selector.vue';
import projectVulnerabilitiesOverTime from 'ee/security_dashboard/graphql/queries/project_vulnerabilities_over_time.query.graphql';
import groupVulnerabilitiesOverTime from 'ee/security_dashboard/graphql/queries/group_vulnerabilities_over_time.query.graphql';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { useFakeDate } from 'helpers/fake_date';
import { mockSecurityAttributesFilters } from '../mock_data';

Vue.use(VueApollo);
jest.mock('~/alert');

describe('VulnerabilitiesOverTimePanel', () => {
  const todayInIsoFormat = '2022-07-06';
  const thirtyDaysAgoInIsoFormat = '2022-06-06';
  const sixtyDaysAgoInIsoFormat = '2022-05-07';
  const thirtyOneDaysAgoInIsoFormat = '2022-06-05';
  const ninetyDaysAgoInIsoFormat = '2022-04-07';
  const sixtyOneDaysAgoInIsoFormat = '2022-05-06';

  useFakeDate(todayInIsoFormat);

  let wrapper;

  const namespaceConfigs = {
    project: {
      namespace: 'project',
      fullPath: 'project-1',
      query: projectVulnerabilitiesOverTime,
      filters: {
        reportType: ['API_FUZZING'],
        trackedRefIds: ['gid://gitlab/Security::ProjectTrackedContext/1'],
      },
      expectedBaseVariables: {
        fullPath: 'project-1',
        reportType: ['API_FUZZING'],
        trackedRefIds: ['gid://gitlab/Security::ProjectTrackedContext/1'],
        severity: [],
        includeBySeverity: true,
        includeByReportType: false,
      },
      shouldIncludeProjectIdFilter: false,
      createMockData: () => ({
        data: {
          namespace: {
            id: 'gid://gitlab/Project/1',
            securityMetrics: {
              vulnerabilitiesOverTime: {
                nodes: [
                  {
                    date: '2022-06-01',
                    bySeverity: [
                      { severity: 'CRITICAL', count: 3 },
                      { severity: 'HIGH', count: 7 },
                    ],
                    byReportType: [{ reportType: 'API_FUZZING', count: 5 }],
                  },
                ],
              },
            },
          },
        },
      }),
    },
    group: {
      namespace: 'group',
      fullPath: 'group/subgroup',
      query: groupVulnerabilitiesOverTime,
      filters: {
        projectId: 'gid://gitlab/Project/123',
        reportType: ['SAST'],
        securityAttributesFilters: mockSecurityAttributesFilters,
      },
      expectedBaseVariables: {
        fullPath: 'group/subgroup',
        projectId: 'gid://gitlab/Project/123',
        reportType: ['SAST'],
        securityAttributesFilters: mockSecurityAttributesFilters,
        severity: [],
        includeBySeverity: true,
        includeByReportType: false,
      },
      shouldIncludeProjectIdFilter: true,
      createMockData: () => ({
        data: {
          namespace: {
            id: 'gid://gitlab/Group/1',
            securityMetrics: {
              vulnerabilitiesOverTime: {
                nodes: [
                  {
                    date: '2022-06-01',
                    bySeverity: [
                      { severity: 'CRITICAL', count: 5 },
                      { severity: 'HIGH', count: 10 },
                    ],
                    byReportType: [{ reportType: 'SAST', count: 8 }],
                  },
                ],
              },
            },
          },
        },
      }),
    },
  };

  const createComponent = ({
    namespace = 'project',
    mockVulnerabilitiesOverTimeHandler = null,
    props = {},
  } = {}) => {
    const config = namespaceConfigs[namespace];
    const defaultMockData = config.createMockData();
    const vulnerabilitiesOverTimeHandler =
      mockVulnerabilitiesOverTimeHandler || jest.fn().mockResolvedValue(defaultMockData);

    const apolloProvider = createMockApollo([[config.query, vulnerabilitiesOverTimeHandler]]);

    wrapper = shallowMountExtended(VulnerabilitiesOverTimePanel, {
      apolloProvider,
      propsData: {
        namespace: config.namespace,
        filters: config.filters,
        ...props,
      },
      provide: {
        fullPath: config.fullPath,
      },
    });

    return { vulnerabilitiesOverTimeHandler, config };
  };

  const findExtendedDashboardPanel = () => wrapper.findComponent(ExtendedDashboardPanel);
  const findVulnerabilitiesOverTimeChart = () =>
    wrapper.findComponent(VulnerabilitiesOverTimeChart);
  const findPanelGroupBy = () => wrapper.findComponent(PanelGroupBy);
  const findOverTimePeriodSelector = () => wrapper.findComponent(OverTimePeriodSelector);
  const findSeverityFilter = () => wrapper.findComponent(PanelSeverityFilter);
  const findEmptyState = () => wrapper.findByTestId('vulnerabilities-over-time-empty-state');

  const clickToggleButtonBy = async (value) => {
    await findPanelGroupBy().vm.$emit('input', value);
    await nextTick();
  };

  describe('component rendering', () => {
    beforeEach(() => {
      createComponent();
    });

    it('passes the correct title to the panels base', () => {
      expect(findExtendedDashboardPanel().props('title')).toBe('Vulnerabilities over time');
    });

    it('passes the correct tooltip to the panels base', () => {
      expect(findExtendedDashboardPanel().props('tooltip')).toEqual({
        description:
          'Open vulnerability trends over time. To interact with a link in a chart popover, click to pin the popover first.',
      });
    });

    it('renders the vulnerabilities over time chart when data is available', async () => {
      await waitForPromises();
      expect(findVulnerabilitiesOverTimeChart().exists()).toBe(true);
    });

    it('passes severity value to PanelGroupBy by default', () => {
      expect(findPanelGroupBy().props('value')).toBe('severity');
    });

    it('renders all filter components', () => {
      expect(findOverTimePeriodSelector().exists()).toBe(true);
      expect(findSeverityFilter().exists()).toBe(true);
      expect(findPanelGroupBy().exists()).toBe(true);
    });

    it('sets initial time period for the chart data to 30 days', () => {
      expect(findOverTimePeriodSelector().props('value')).toBe(30);
    });
  });

  describe('data fetching', () => {
    it('re-fetches data when time period changes', async () => {
      const { vulnerabilitiesOverTimeHandler } = createComponent();
      await waitForPromises();

      const initialCallCount = vulnerabilitiesOverTimeHandler.mock.calls.length;

      await findOverTimePeriodSelector().vm.$emit('input', 60);
      await waitForPromises();

      expect(vulnerabilitiesOverTimeHandler.mock.calls.length).toBeGreaterThan(initialCallCount);
    });
  });

  describe('time period selection', () => {
    it('fetches only 30-day chunk for default period', async () => {
      const { vulnerabilitiesOverTimeHandler, config } = createComponent();
      await waitForPromises();

      expect(vulnerabilitiesOverTimeHandler).toHaveBeenCalledTimes(1);

      expect(vulnerabilitiesOverTimeHandler).toHaveBeenCalledWith({
        ...config.expectedBaseVariables,
        startDate: thirtyDaysAgoInIsoFormat,
        endDate: todayInIsoFormat,
      });
    });

    it('fetches 30-day and 60-day chunks when period is set to 60', async () => {
      const { vulnerabilitiesOverTimeHandler } = createComponent();

      await findOverTimePeriodSelector().vm.$emit('input', 60);
      await waitForPromises();

      expect(vulnerabilitiesOverTimeHandler).toHaveBeenCalledTimes(2);

      expect(vulnerabilitiesOverTimeHandler).toHaveBeenCalledWith(
        expect.objectContaining({
          startDate: thirtyDaysAgoInIsoFormat,
          endDate: todayInIsoFormat,
        }),
      );

      expect(vulnerabilitiesOverTimeHandler).toHaveBeenCalledWith(
        expect.objectContaining({
          startDate: sixtyDaysAgoInIsoFormat,
          endDate: thirtyOneDaysAgoInIsoFormat,
        }),
      );
    });

    it('fetches all three chunks when period is set to 90', async () => {
      const { vulnerabilitiesOverTimeHandler } = createComponent();

      await findOverTimePeriodSelector().vm.$emit('input', 90);
      await waitForPromises();

      expect(vulnerabilitiesOverTimeHandler).toHaveBeenCalledTimes(3);

      expect(vulnerabilitiesOverTimeHandler).toHaveBeenCalledWith(
        expect.objectContaining({
          startDate: thirtyDaysAgoInIsoFormat,
          endDate: todayInIsoFormat,
        }),
      );

      expect(vulnerabilitiesOverTimeHandler).toHaveBeenCalledWith(
        expect.objectContaining({
          startDate: sixtyDaysAgoInIsoFormat,
          endDate: thirtyOneDaysAgoInIsoFormat,
        }),
      );

      expect(vulnerabilitiesOverTimeHandler).toHaveBeenCalledWith(
        expect.objectContaining({
          startDate: ninetyDaysAgoInIsoFormat,
          endDate: sixtyOneDaysAgoInIsoFormat,
        }),
      );
    });

    it('initializes time period if URL parameter is set', () => {
      setWindowLocation('?vulnerabilitiesOverTime.timePeriod=60');
      createComponent();

      expect(findOverTimePeriodSelector().props('value')).toEqual(60);
    });

    it('calls writeToUrl when time period is set', async () => {
      jest.spyOn(panelStateUrlSync, 'writeToUrl');
      createComponent();

      await findOverTimePeriodSelector().vm.$emit('input', 90);
      expect(panelStateUrlSync.writeToUrl).toHaveBeenCalledWith({
        panelId: 'vulnerabilitiesOverTime',
        paramName: 'timePeriod',
        value: 90,
        defaultValue: 30,
      });
    });
  });

  describe('filters', () => {
    it('updates GraphQL query when severity filter changes', async () => {
      const { vulnerabilitiesOverTimeHandler } = createComponent();
      const appliedFilters = ['CRITICAL', 'HIGH'];

      await waitForPromises();
      const initialCallCount = vulnerabilitiesOverTimeHandler.mock.calls.length;

      await findSeverityFilter().vm.$emit('input', appliedFilters);
      await waitForPromises();

      expect(vulnerabilitiesOverTimeHandler.mock.calls.length).toBeGreaterThan(initialCallCount);
      expect(vulnerabilitiesOverTimeHandler).toHaveBeenCalledWith(
        expect.objectContaining({
          severity: appliedFilters,
        }),
      );
    });

    it('initializes severity if URL parameter is set', () => {
      setWindowLocation('?vulnerabilitiesOverTime.severity=HIGH%2CLOW');
      createComponent();

      expect(findSeverityFilter().props('value')).toMatchObject(['HIGH', 'LOW']);
    });

    it('calls writeToUrl when severity is set', async () => {
      jest.spyOn(panelStateUrlSync, 'writeToUrl');
      createComponent();

      await findSeverityFilter().vm.$emit('input', ['CRITICAL', 'MEDIUM']);
      expect(panelStateUrlSync.writeToUrl).toHaveBeenCalledWith({
        panelId: 'vulnerabilitiesOverTime',
        paramName: 'severity',
        value: ['CRITICAL', 'MEDIUM'],
        defaultValue: [],
      });
    });
  });

  describe('group by functionality', () => {
    beforeEach(() => {
      createComponent();
    });

    it('switches to report type grouping when report type button is clicked', async () => {
      await waitForPromises();
      await clickToggleButtonBy('reportType');

      expect(findPanelGroupBy().props('value')).toBe('reportType');
    });

    it('switches back to severity grouping when severity button is clicked', async () => {
      await waitForPromises();
      await clickToggleButtonBy('reportType');
      await clickToggleButtonBy('severity');

      expect(findPanelGroupBy().props('value')).toBe('severity');
    });

    it('initializes with report type grouping if URL parameter is set', () => {
      setWindowLocation('?vulnerabilitiesOverTime.groupBy=reportType');
      createComponent();

      expect(findPanelGroupBy().props('value')).toBe('reportType');
    });

    it('calls writeToUrl when grouping is set to report type', async () => {
      jest.spyOn(panelStateUrlSync, 'writeToUrl');

      await clickToggleButtonBy('reportType');

      expect(panelStateUrlSync.writeToUrl).toHaveBeenCalledWith({
        panelId: 'vulnerabilitiesOverTime',
        paramName: 'groupBy',
        value: 'reportType',
        defaultValue: 'severity',
      });
    });
  });

  describe('loading state', () => {
    const namespace = 'project';

    it('shows loading state initially', () => {
      createComponent({ namespace });

      expect(findExtendedDashboardPanel().props('loading')).toBe(true);
    });

    it('hides loading state after data is loaded', async () => {
      createComponent({ namespace });
      await waitForPromises();

      expect(findExtendedDashboardPanel().props('loading')).toBe(false);
    });

    it('shows loading state when switching time periods', async () => {
      createComponent({ namespace });
      await waitForPromises();

      expect(findExtendedDashboardPanel().props('loading')).toBe(false);

      await findOverTimePeriodSelector().vm.$emit('input', 60);

      expect(findExtendedDashboardPanel().props('loading')).toBe(true);

      await waitForPromises();

      expect(findExtendedDashboardPanel().props('loading')).toBe(false);
    });
  });

  describe('error handling', () => {
    const namespace = 'project';

    it('shows error state when GraphQL query fails', async () => {
      createComponent({
        namespace,
        mockVulnerabilitiesOverTimeHandler: jest.fn().mockRejectedValue(new Error('GraphQL error')),
      });

      await waitForPromises();

      expect(findExtendedDashboardPanel().props('showAlertState')).toBe(true);
      expect(findVulnerabilitiesOverTimeChart().exists()).toBe(false);
      expect(findEmptyState().text()).toBe('Something went wrong. Please try again.');
    });

    it('shows error state when server returns error response', async () => {
      createComponent({
        namespace,
        mockVulnerabilitiesOverTimeHandler: jest.fn().mockResolvedValue({
          errors: [{ message: 'Internal server error' }],
        }),
      });

      await waitForPromises();

      expect(findExtendedDashboardPanel().props('showAlertState')).toBe(true);
      expect(findVulnerabilitiesOverTimeChart().exists()).toBe(false);
      expect(findEmptyState().text()).toBe('Something went wrong. Please try again.');
    });

    it('handles error when switching time periods', async () => {
      const config = namespaceConfigs[namespace];
      const mockHandler = jest
        .fn()
        .mockResolvedValueOnce(config.createMockData())
        .mockRejectedValueOnce(new Error('Network error'));

      createComponent({
        namespace,
        mockVulnerabilitiesOverTimeHandler: mockHandler,
      });

      await waitForPromises();

      expect(findExtendedDashboardPanel().props('showAlertState')).toBe(false);
      expect(findVulnerabilitiesOverTimeChart().exists()).toBe(true);

      await findOverTimePeriodSelector().vm.$emit('input', 60);
      await waitForPromises();

      expect(findExtendedDashboardPanel().props('showAlertState')).toBe(true);
      expect(findVulnerabilitiesOverTimeChart().exists()).toBe(false);
      expect(findEmptyState().text()).toBe('Something went wrong. Please try again.');
    });

    it('handles partial chunk failures gracefully', async () => {
      const config = namespaceConfigs[namespace];
      const mockHandler = jest
        .fn()
        .mockResolvedValueOnce(config.createMockData())
        .mockRejectedValueOnce(new Error('Network timeout'));

      createComponent({
        namespace,
        mockVulnerabilitiesOverTimeHandler: mockHandler,
      });

      await findOverTimePeriodSelector().vm.$emit('input', 60);
      await waitForPromises();

      expect(findExtendedDashboardPanel().props('showAlertState')).toBe(true);
      expect(findVulnerabilitiesOverTimeChart().exists()).toBe(false);
      expect(findEmptyState().text()).toBe('Something went wrong. Please try again.');
    });

    it('handles error during filter changes', async () => {
      const config = namespaceConfigs[namespace];
      const mockHandler = jest
        .fn()
        .mockResolvedValueOnce(config.createMockData())
        .mockRejectedValueOnce(new Error('Filter error'));

      createComponent({
        namespace,
        mockVulnerabilitiesOverTimeHandler: mockHandler,
      });

      await waitForPromises();

      expect(findExtendedDashboardPanel().props('showAlertState')).toBe(false);

      await findSeverityFilter().vm.$emit('input', ['CRITICAL']);
      await waitForPromises();

      expect(findExtendedDashboardPanel().props('showAlertState')).toBe(true);
      expect(findVulnerabilitiesOverTimeChart().exists()).toBe(false);
    });

    it('resets error state when retrying after successful data fetch', async () => {
      const config = namespaceConfigs[namespace];
      const mockHandler = jest
        .fn()
        .mockRejectedValueOnce(new Error('Initial error'))
        .mockResolvedValue(config.createMockData());

      createComponent({
        namespace,
        mockVulnerabilitiesOverTimeHandler: mockHandler,
      });

      await waitForPromises();

      expect(findExtendedDashboardPanel().props('showAlertState')).toBe(true);
      expect(findVulnerabilitiesOverTimeChart().exists()).toBe(false);

      await findOverTimePeriodSelector().vm.$emit('input', 60);
      await waitForPromises();

      expect(findExtendedDashboardPanel().props('showAlertState')).toBe(false);
      expect(findVulnerabilitiesOverTimeChart().exists()).toBe(true);
    });
  });

  describe.each(['project', 'group'])('when namespace is "%s"', (namespace) => {
    it('fetches data with the correct variables and fullPath', async () => {
      const { vulnerabilitiesOverTimeHandler, config } = createComponent({ namespace });
      await waitForPromises();

      expect(vulnerabilitiesOverTimeHandler).toHaveBeenCalledWith({
        ...config.expectedBaseVariables,
        startDate: thirtyDaysAgoInIsoFormat,
        endDate: todayInIsoFormat,
      });
    });

    it('handles the projectId filter correctly based on namespace', async () => {
      const { vulnerabilitiesOverTimeHandler, config } = createComponent({ namespace });
      await waitForPromises();

      if (config.shouldIncludeProjectIdFilter) {
        expect(vulnerabilitiesOverTimeHandler).toHaveBeenCalledWith(
          expect.objectContaining({ projectId: expect.anything() }),
        );
      } else {
        expect(vulnerabilitiesOverTimeHandler).toHaveBeenCalledWith(
          expect.not.objectContaining({ projectId: expect.anything() }),
        );
      }
    });
  });
});
