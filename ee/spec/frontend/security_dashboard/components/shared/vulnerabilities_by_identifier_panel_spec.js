import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import setWindowLocation from 'helpers/set_window_location_helper';
import waitForPromises from 'helpers/wait_for_promises';
import createMockApollo from 'helpers/mock_apollo_helper';
import ExtendedDashboardPanel from '~/vue_shared/components/customizable_dashboard/extended_dashboard_panel.vue';
import VulnerabilitiesByIdentifierPanel from 'ee/security_dashboard/components/shared/vulnerabilities_by_identifier_panel.vue';
import VulnerabilitiesByIdentifierChart from 'ee/security_dashboard/components/shared/charts/vulnerabilities_by_identifier_chart.vue';
import groupVulnerabilitiesByIdentifier from 'ee/security_dashboard/graphql/queries/group_vulnerabilities_by_identifier.query.graphql';
import projectVulnerabilitiesByIdentifier from 'ee/security_dashboard/graphql/queries/project_vulnerabilities_by_identifier.query.graphql';
import organizationVulnerabilitiesByIdentifier from 'ee/security_dashboard/graphql/queries/organization_vulnerabilities_by_identifier.query.graphql';
import * as panelStateUrlSync from 'ee/security_dashboard/utils/panel_state_url_sync';
import PanelSeverityFilter from 'ee/security_dashboard/components/shared/panel_severity_filter.vue';
import { mockSecurityAttributesFilters } from '../mock_data';

Vue.use(VueApollo);

describe('VulnerabilitiesByIdentifierPanel', () => {
  let wrapper;
  let vulnerabilitiesByIdentifierHandler;

  const mockGroupFullPath = 'group/subgroup';
  const mockProjectFullPath = 'namespace/project';
  const mockFilters = {
    projectId: ['gid://gitlab/Project/123'],
    securityAttributesFilters: mockSecurityAttributesFilters,
  };
  const vulnerabilitiesByIdentifier = [
    {
      name: 'CWE-79',
      url: 'https://cwe.mitre.org/data/definitions/79.html',
      bySeverity: [
        { severity: 'CRITICAL', count: 12 },
        { severity: 'HIGH', count: 24 },
      ],
    },
    {
      name: 'CWE-89',
      url: 'https://cwe.mitre.org/data/definitions/89.html',
      bySeverity: [
        { severity: 'CRITICAL', count: 15 },
        { severity: 'HIGH', count: 10 },
      ],
    },
  ];
  const defaultMockResponse = {
    data: {
      namespace: {
        id: 'gid://gitlab/Group/1',
        securityMetrics: {
          __typename: 'SecurityMetrics',
          vulnerabilitiesByIdentifier,
        },
      },
    },
  };

  const createComponent = ({
    namespace = 'group',
    props,
    mockHandler = null,
    fullPath = mockGroupFullPath,
    query = groupVulnerabilitiesByIdentifier,
  } = {}) => {
    vulnerabilitiesByIdentifierHandler =
      mockHandler || jest.fn().mockResolvedValue(defaultMockResponse);
    const apolloProvider = createMockApollo([[query, vulnerabilitiesByIdentifierHandler]]);

    wrapper = shallowMountExtended(VulnerabilitiesByIdentifierPanel, {
      apolloProvider,
      provide: {
        fullPath,
        securityVulnerabilitiesPath: '/group/security/vulnerabilities',
      },
      propsData: {
        namespace,
        filters: mockFilters,
        ...props,
      },
    });
  };
  const findExtendedDashboardPanel = () => wrapper.findComponent(ExtendedDashboardPanel);
  const findChart = () => wrapper.findComponent(VulnerabilitiesByIdentifierChart);
  const findSeverityFilter = () => wrapper.findComponent(PanelSeverityFilter);
  const findEmptyState = () => wrapper.findByTestId('vulnerabilities-by-identifier-empty-state');

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
      expect(findExtendedDashboardPanel().props('title')).toBe('Top 10 CWEs');
    });

    it('passes the correct tooltip to the panel', () => {
      expect(findExtendedDashboardPanel().props('tooltip')).toEqual({
        description: 'Open vulnerabilities by their top ten most common CWE identifiers.',
      });
    });

    it('renders the severity filter', () => {
      expect(findSeverityFilter().exists()).toBe(true);
    });

    it('renders the chart when data is available', async () => {
      await waitForPromises();

      expect(findChart().props()).toMatchObject({
        vulnerabilitiesByIdentifier,
        filters: mockFilters,
      });
    });

    it('does not render empty state when data is available', async () => {
      await waitForPromises();

      expect(findEmptyState().exists()).toBe(false);
    });
  });

  describe('Apollo query', () => {
    it('fetches vulnerabilities by identifier when component is created', () => {
      expect(vulnerabilitiesByIdentifierHandler).toHaveBeenCalledWith({
        fullPath: mockGroupFullPath,
        projectId: mockFilters.projectId,
        securityAttributesFilters: mockSecurityAttributesFilters,
        severity: [],
      });
    });

    it('passes page level filters to the GraphQL query', () => {
      createComponent({
        props: {
          filters: { projectId: ['gid://gitlab/Project/99'] },
        },
      });

      expect(vulnerabilitiesByIdentifierHandler).toHaveBeenCalledWith(
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
      setWindowLocation('?vulnerabilitiesByIdentifier.severity=HIGH%2CLOW');
      createComponent();

      expect(findSeverityFilter().props('value')).toMatchObject(['HIGH', 'LOW']);
    });

    it('calls writeToUrl when severity is set', async () => {
      jest.spyOn(panelStateUrlSync, 'writeToUrl');
      createComponent();

      await findSeverityFilter().vm.$emit('input', ['CRITICAL', 'MEDIUM']);
      expect(panelStateUrlSync.writeToUrl).toHaveBeenCalledWith({
        panelId: 'vulnerabilitiesByIdentifier',
        paramName: 'severity',
        value: ['CRITICAL', 'MEDIUM'],
        defaultValue: [],
      });
    });

    it('passes correct severity to the GraphQL query', async () => {
      await findSeverityFilter().vm.$emit('input', ['CRITICAL', 'MEDIUM']);

      expect(vulnerabilitiesByIdentifierHandler).toHaveBeenCalledWith({
        fullPath: mockGroupFullPath,
        projectId: mockFilters.projectId,
        securityAttributesFilters: mockSecurityAttributesFilters,
        severity: ['CRITICAL', 'MEDIUM'],
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
        mockHandler: jest.fn().mockRejectedValue(new Error('GraphQL error')),
      });

      await waitForPromises();

      expect(findExtendedDashboardPanel().props('showAlertState')).toBe(true);
      expect(findChart().exists()).toBe(false);
      expect(findEmptyState().text()).toBe('Something went wrong. Please try again.');
    });

    it('shows error state when server returns error response', async () => {
      createComponent({
        mockHandler: jest.fn().mockResolvedValue({
          errors: [{ message: 'Internal server error' }],
        }),
      });

      await waitForPromises();

      expect(findExtendedDashboardPanel().props('showAlertState')).toBe(true);
      expect(findChart().exists()).toBe(false);
      expect(findEmptyState().text()).toBe('Something went wrong. Please try again.');
    });

    it('resets hasFetchError when a new fetch begins', async () => {
      const mockHandler = jest
        .fn()
        .mockRejectedValueOnce(new Error('GraphQL query failed'))
        .mockResolvedValue(defaultMockResponse);

      createComponent({ mockHandler });

      await waitForPromises();

      expect(findEmptyState().text()).toBe('Something went wrong. Please try again.');

      await findSeverityFilter().vm.$emit('input', ['CRITICAL', 'MEDIUM']);

      await waitForPromises();

      expect(findEmptyState().exists()).toBe(false);
    });
  });

  describe('when namespace is "project"', () => {
    const projectMockData = {
      data: {
        namespace: {
          id: 'gid://gitlab/Project/1',
          securityMetrics: {
            __typename: 'SecurityMetrics',
            vulnerabilitiesByIdentifier,
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
        query: projectVulnerabilitiesByIdentifier,
        props: { filters: projectFilters },
        mockHandler: jest.fn().mockResolvedValue(projectMockData),
      });
    });

    it('uses the project-level query with correct variables', () => {
      expect(vulnerabilitiesByIdentifierHandler).toHaveBeenCalledWith({
        fullPath: mockProjectFullPath,
        reportType: projectFilters.reportType,
        trackedRefIds: projectFilters.trackedRefIds,
        severity: [],
      });
    });

    it('does not pass group-level filters (projectId, securityAttributesFilters)', () => {
      expect(vulnerabilitiesByIdentifierHandler).toHaveBeenCalledWith(
        expect.not.objectContaining({
          projectId: expect.anything(),
          securityAttributesFilters: expect.anything(),
        }),
      );
    });

    it('renders chart data from namespace response', async () => {
      await waitForPromises();

      expect(findChart().exists()).toBe(true);
    });
  });

  describe.each(['project', 'group', 'organization'])('when namespace is "%s"', (namespace) => {
    it('uses the correct query for the namespace', () => {
      const query = {
        project: projectVulnerabilitiesByIdentifier,
        group: groupVulnerabilitiesByIdentifier,
        organization: organizationVulnerabilitiesByIdentifier,
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

      expect(vulnerabilitiesByIdentifierHandler).toHaveBeenCalledWith(
        expect.objectContaining({
          fullPath,
          severity: [],
        }),
      );
    });
  });
});
