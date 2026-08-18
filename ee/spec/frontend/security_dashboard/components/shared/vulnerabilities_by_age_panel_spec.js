import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import setWindowLocation from 'helpers/set_window_location_helper';
import waitForPromises from 'helpers/wait_for_promises';
import createMockApollo from 'helpers/mock_apollo_helper';
import ExtendedDashboardPanel from '~/vue_shared/components/customizable_dashboard/extended_dashboard_panel.vue';
import VulnerabilitiesByAgeChart from 'ee/security_dashboard/components/shared/charts/vulnerabilities_by_age_chart.vue';
import VulnerabilitiesByAgePanel from 'ee/security_dashboard/components/shared/vulnerabilities_by_age_panel.vue';
import { formatVulnerabilitiesBySeries } from 'ee/security_dashboard/utils/chart_utils';
import groupVulnerabilitiesByAge from 'ee/security_dashboard/graphql/queries/group_vulnerabilities_by_age.query.graphql';
import projectVulnerabilitiesByAge from 'ee/security_dashboard/graphql/queries/project_vulnerabilities_by_age.query.graphql';
import organizationVulnerabilitiesByAge from 'ee/security_dashboard/graphql/queries/organization_vulnerabilities_by_age.query.graphql';
import * as panelStateUrlSync from 'ee/security_dashboard/utils/panel_state_url_sync';
import PanelGroupBy from 'ee/security_dashboard/components/shared/panel_group_by.vue';
import PanelSeverityFilter from 'ee/security_dashboard/components/shared/panel_severity_filter.vue';
import { mockSecurityAttributesFilters } from '../mock_data';

Vue.use(VueApollo);

describe('VulnerabilitiesByAgePanel', () => {
  let wrapper;
  let vulnerabilitiesByAgeHandler;

  const mockGroupFullPath = 'group/subgroup';
  const mockProjectFullPath = 'namespace/project';
  const mockFilters = {
    projectId: ['gid://gitlab/Project/123'],
    securityAttributesFilters: mockSecurityAttributesFilters,
  };
  const vulnerabilitiesByAge = [
    {
      name: '<7 days',
      bySeverity: [
        {
          severity: 'CRITICAL',
          count: 10,
        },
        {
          severity: 'HIGH',
          count: 5,
        },
      ],
      byReportType: [
        {
          reportType: 'SAST',
          count: 1,
        },
        {
          reportType: 'DAST',
          count: 2,
        },
      ],
    },
    {
      name: '7-14 days',
      bySeverity: [
        {
          severity: 'CRITICAL',
          count: 2,
        },
        {
          severity: 'HIGH',
          count: 7,
        },
      ],
      byReportType: [
        {
          reportType: 'SAST',
          count: 5,
        },
        {
          reportType: 'DAST',
          count: 8,
        },
      ],
    },
  ];
  const defaultMockVulnerabilitiesByAge = {
    data: {
      namespace: {
        id: 'gid://gitlab/Group/1',
        securityMetrics: {
          __typename: 'SecurityMetrics',
          vulnerabilitiesByAge,
        },
      },
    },
  };

  const createComponent = ({
    namespace = 'group',
    props,
    mockVulnerabilitiesByAgeHandler = null,
    fullPath = mockGroupFullPath,
    query = groupVulnerabilitiesByAge,
  } = {}) => {
    vulnerabilitiesByAgeHandler =
      mockVulnerabilitiesByAgeHandler ||
      jest.fn().mockResolvedValue(defaultMockVulnerabilitiesByAge);
    const apolloProvider = createMockApollo([[query, vulnerabilitiesByAgeHandler]]);

    wrapper = shallowMountExtended(VulnerabilitiesByAgePanel, {
      apolloProvider,
      provide: {
        fullPath,
      },
      propsData: {
        namespace,
        filters: mockFilters,
        ...props,
      },
    });
  };

  const findExtendedDashboardPanel = () => wrapper.findComponent(ExtendedDashboardPanel);
  const findVulnerabilitiesByAgeChart = () => wrapper.findComponent(VulnerabilitiesByAgeChart);
  const findPanelGroupBy = () => wrapper.findComponent(PanelGroupBy);
  const findSeverityFilter = () => wrapper.findComponent(PanelSeverityFilter);
  const findEmptyState = () => wrapper.findByTestId('vulnerabilities-by-age-empty-state');

  const clickToggleButtonBy = async (value) => {
    await findPanelGroupBy().vm.$emit('input', value);
    await nextTick();
  };

  beforeEach(() => {
    createComponent();
  });

  afterEach(() => {
    setWindowLocation('');
  });

  describe('component rendering', () => {
    it('renders the extended dashboard panel', () => {
      expect(findExtendedDashboardPanel().exists()).toBe(true);
    });

    it('passes the correct title to the panel', () => {
      expect(findExtendedDashboardPanel().props('title')).toBe('Vulnerabilities by age');
    });

    it('passes the correct tooltip to the panels base', () => {
      expect(findExtendedDashboardPanel().props('tooltip')).toEqual({
        description: 'Open vulnerabilities by the amount of time since they were opened.',
      });
    });

    it('renders the vulnerabilities by age chart when data is available', async () => {
      await waitForPromises();
      const bars = formatVulnerabilitiesBySeries(vulnerabilitiesByAge, { isStacked: true });
      expect(findVulnerabilitiesByAgeChart().props()).toMatchObject({
        bars,
        labels: ['<7 days', '7-14 days'],
      });
    });

    it('passes severity value to PanelGroupBy by default', () => {
      expect(findPanelGroupBy().props('value')).toBe('severity');
    });

    it('renders all filter components', () => {
      expect(findSeverityFilter().exists()).toBe(true);
      expect(findPanelGroupBy().exists()).toBe(true);
    });
  });

  describe('Apollo query', () => {
    it('fetches vulnerabilities by age when component is created', () => {
      expect(vulnerabilitiesByAgeHandler).toHaveBeenCalledWith({
        fullPath: mockGroupFullPath,
        projectId: mockFilters.projectId,
        securityAttributesFilters: mockSecurityAttributesFilters,
        severity: [],
        includeBySeverity: true,
        includeByReportType: false,
      });
    });

    it('passes page level filters to the GraphQL query', () => {
      createComponent({
        props: {
          filters: { projectId: ['gid://gitlab/Project/99'] },
        },
      });

      expect(vulnerabilitiesByAgeHandler).toHaveBeenCalledWith(
        expect.objectContaining({
          fullPath: mockGroupFullPath,
          projectId: ['gid://gitlab/Project/99'],
          severity: [],
        }),
      );
    });
  });

  describe('filters', () => {
    it('initializes severity if URL parameter is set', () => {
      setWindowLocation('?vulnerabilitiesByAge.severity=HIGH%2CLOW');
      createComponent();

      expect(findSeverityFilter().props('value')).toMatchObject(['HIGH', 'LOW']);
    });

    it('calls writeToUrl when severity is set', async () => {
      jest.spyOn(panelStateUrlSync, 'writeToUrl');
      createComponent();

      await findSeverityFilter().vm.$emit('input', ['CRITICAL', 'MEDIUM']);
      expect(panelStateUrlSync.writeToUrl).toHaveBeenCalledWith({
        panelId: 'vulnerabilitiesByAge',
        paramName: 'severity',
        value: ['CRITICAL', 'MEDIUM'],
        defaultValue: [],
      });
    });

    it('passes correct severity to the GraphQL query', async () => {
      await findSeverityFilter().vm.$emit('input', ['CRITICAL', 'MEDIUM']);

      expect(vulnerabilitiesByAgeHandler).toHaveBeenCalledWith({
        fullPath: mockGroupFullPath,
        projectId: mockFilters.projectId,
        securityAttributesFilters: mockSecurityAttributesFilters,
        severity: ['CRITICAL', 'MEDIUM'],
        includeBySeverity: true,
        includeByReportType: false,
      });
    });
  });

  describe('group by functionality', () => {
    describe('when report type button is clicked', () => {
      beforeEach(() => {
        clickToggleButtonBy('reportType');
      });
      it('switches to report type grouping', () => {
        expect(findPanelGroupBy().props('value')).toBe('reportType');
      });

      it('sets `includeByReportType` to true and `includeBySeverity` to false', async () => {
        await waitForPromises();

        expect(vulnerabilitiesByAgeHandler).toHaveBeenCalledWith({
          fullPath: mockGroupFullPath,
          projectId: mockFilters.projectId,
          securityAttributesFilters: mockSecurityAttributesFilters,
          severity: [],
          includeBySeverity: false,
          includeByReportType: true,
        });
      });
    });

    it('switches to report type grouping when report type button is clicked', async () => {
      await clickToggleButtonBy('reportType');

      expect(findPanelGroupBy().props('value')).toBe('reportType');
    });

    it('switches back to severity grouping when severity button is clicked', async () => {
      await clickToggleButtonBy('reportType');
      await clickToggleButtonBy('severity');

      expect(findPanelGroupBy().props('value')).toBe('severity');
    });

    it('initializes with report type grouping if URL parameter is set', () => {
      setWindowLocation('?vulnerabilitiesByAge.groupBy=reportType');
      createComponent();

      expect(findPanelGroupBy().props('value')).toBe('reportType');
    });

    it('calls writeToUrl when grouping is set to report type', async () => {
      jest.spyOn(panelStateUrlSync, 'writeToUrl');

      await clickToggleButtonBy('reportType');

      expect(panelStateUrlSync.writeToUrl).toHaveBeenCalledWith({
        panelId: 'vulnerabilitiesByAge',
        paramName: 'groupBy',
        value: 'reportType',
        defaultValue: 'severity',
      });
    });
  });

  describe('loading state', () => {
    it('shows loading state initially', () => {
      expect(findExtendedDashboardPanel().props('loading')).toBe(true);
    });

    it('hides loading state after data is loaded', async () => {
      await waitForPromises();

      expect(findExtendedDashboardPanel().props('loading')).toBe(false);
    });
  });

  describe('error handling', () => {
    it('shows error state when GraphQL query fails', async () => {
      createComponent({
        mockVulnerabilitiesByAgeHandler: jest.fn().mockRejectedValue(new Error('GraphQL error')),
      });

      await waitForPromises();

      expect(findExtendedDashboardPanel().props('showAlertState')).toBe(true);
      expect(findVulnerabilitiesByAgeChart().exists()).toBe(false);
      expect(findEmptyState().text()).toBe('Something went wrong. Please try again.');
    });

    it('shows error state when server returns error response', async () => {
      createComponent({
        mockVulnerabilitiesByAgeHandler: jest.fn().mockResolvedValue({
          errors: [{ message: 'Internal server error' }],
        }),
      });

      await waitForPromises();

      expect(findExtendedDashboardPanel().props('showAlertState')).toBe(true);
      expect(findVulnerabilitiesByAgeChart().exists()).toBe(false);
      expect(findEmptyState().text()).toBe('Something went wrong. Please try again.');
    });

    it('resets hasFetchError when a new fetch begins', async () => {
      const mockVulnerabilitiesByAgeHandler = jest
        .fn()
        .mockRejectedValueOnce(new Error('GraphQL error'))
        .mockResolvedValue(defaultMockVulnerabilitiesByAge);

      createComponent({ mockVulnerabilitiesByAgeHandler });

      await waitForPromises();

      expect(findExtendedDashboardPanel().props('showAlertState')).toBe(true);

      await findPanelGroupBy().vm.$emit('input', 'reportType');
      await waitForPromises();

      expect(findExtendedDashboardPanel().props('showAlertState')).toBe(false);
    });
  });

  describe('when namespace is "project"', () => {
    const projectMockData = {
      data: {
        namespace: {
          id: 'gid://gitlab/Project/1',
          securityMetrics: {
            __typename: 'SecurityMetrics',
            vulnerabilitiesByAge,
          },
        },
      },
    };
    const projectFilters = {
      reportType: ['SAST'],
      trackedRefIds: ['gid://gitlab/Security::ProjectTrackedContext/1'],
    };

    beforeEach(() => {
      createComponent({
        namespace: 'project',
        fullPath: mockProjectFullPath,
        query: projectVulnerabilitiesByAge,
        props: { filters: projectFilters },
        mockVulnerabilitiesByAgeHandler: jest.fn().mockResolvedValue(projectMockData),
      });
    });

    it('uses the project-level query with correct variables', () => {
      expect(vulnerabilitiesByAgeHandler).toHaveBeenCalledWith({
        fullPath: mockProjectFullPath,
        reportType: projectFilters.reportType,
        trackedRefIds: projectFilters.trackedRefIds,
        severity: [],
        includeBySeverity: true,
        includeByReportType: false,
      });
    });

    it('does not pass group-level filters (projectId, securityAttributesFilters)', () => {
      expect(vulnerabilitiesByAgeHandler).toHaveBeenCalledWith(
        expect.not.objectContaining({
          projectId: expect.anything(),
          securityAttributesFilters: expect.anything(),
        }),
      );
    });

    it('renders chart data from namespace response', async () => {
      await waitForPromises();

      expect(findVulnerabilitiesByAgeChart().exists()).toBe(true);
    });
  });

  describe.each(['project', 'group', 'organization'])('when namespace is "%s"', (namespace) => {
    it('uses the correct query for the namespace', () => {
      const query = {
        project: projectVulnerabilitiesByAge,
        group: groupVulnerabilitiesByAge,
        organization: organizationVulnerabilitiesByAge,
      }[namespace];
      const fullPath = {
        project: mockProjectFullPath,
        group: mockGroupFullPath,
        organization: null,
      }[namespace];
      const filters = {
        project: { reportType: ['SAST'] },
        group: mockFilters,
        organization: { projectId: ['gid://gitlab/Project/123'], reportType: ['SAST'] },
      }[namespace];

      createComponent({
        namespace,
        fullPath,
        query,
        props: { filters },
      });

      expect(vulnerabilitiesByAgeHandler).toHaveBeenCalledWith(
        expect.objectContaining({
          fullPath,
          severity: [],
          includeBySeverity: true,
          includeByReportType: false,
        }),
      );
    });
  });
});
