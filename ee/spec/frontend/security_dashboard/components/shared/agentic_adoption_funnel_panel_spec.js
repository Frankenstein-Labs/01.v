import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import waitForPromises from 'helpers/wait_for_promises';
import createMockApollo from 'helpers/mock_apollo_helper';
import { useFakeDate } from 'helpers/fake_date';
import setWindowLocation from 'helpers/set_window_location_helper';
import ExtendedDashboardPanel from '~/vue_shared/components/customizable_dashboard/extended_dashboard_panel.vue';
import AgenticAdoptionFunnelPanel from 'ee/security_dashboard/components/shared/agentic_adoption_funnel_panel.vue';
import AgenticAdoptionFunnelChart from 'ee/security_dashboard/components/shared/charts/agentic_adoption_funnel_chart.vue';
import OverTimePeriodSelector from 'ee/security_dashboard/components/shared/over_time_period_selector.vue';
import groupVulnerabilityResolutionFunnel from 'ee/security_dashboard/graphql/queries/group_vulnerability_resolution_funnel.query.graphql';
import projectVulnerabilityResolutionFunnel from 'ee/security_dashboard/graphql/queries/project_vulnerability_resolution_funnel.query.graphql';
import organizationVulnerabilityResolutionFunnel from 'ee/security_dashboard/graphql/queries/organization_vulnerability_resolution_funnel.query.graphql';
import * as panelStateUrlSync from 'ee/security_dashboard/utils/panel_state_url_sync';
import { mockSecurityAttributesFilters } from '../mock_data';

Vue.use(VueApollo);

describe('AgenticAdoptionFunnelPanel', () => {
  // Pin the clock so the derived startDate/endDate are deterministic.
  useFakeDate(2026, 5, 5); // 2026-06-05 (month is zero-based)

  let wrapper;
  let funnelHandler;

  const mockGroupFullPath = 'group/subgroup';
  const mockProjectFullPath = 'namespace/project';
  const mockGroupFilters = {
    projectId: ['gid://gitlab/Project/123'],
    securityAttributesFilters: mockSecurityAttributesFilters,
    reportType: ['SAST'],
  };

  const funnelData = {
    __typename: 'VulnerabilityResolutionFunnel',
    detectedVulnerabilities: {
      __typename: 'VulnerabilityFunnelStep',
      count: 1240,
      status: 'AVAILABLE',
      canEnable: null,
    },
    truePositives: {
      __typename: 'VulnerabilityFunnelStep',
      count: 870,
      status: 'AVAILABLE',
      canEnable: null,
    },
    createdMergeRequests: {
      __typename: 'VulnerabilityFunnelStep',
      count: 287,
      status: 'AVAILABLE',
      canEnable: null,
    },
    mergedMergeRequests: {
      __typename: 'VulnerabilityFunnelStep',
      count: 175,
      status: 'AVAILABLE',
      canEnable: null,
    },
  };

  const serverResponse = (typename = 'Group', idValue = 'gid://gitlab/Group/1') => ({
    data: {
      namespace: {
        __typename: typename,
        id: idValue,
        securityMetrics: {
          __typename: 'SecurityMetrics',
          vulnerabilityResolutionFunnel: funnelData,
        },
      },
    },
  });

  const createComponent = ({
    namespace = 'group',
    props,
    mockHandler = null,
    fullPath = mockGroupFullPath,
    query = groupVulnerabilityResolutionFunnel,
  } = {}) => {
    funnelHandler = mockHandler || jest.fn().mockResolvedValue(serverResponse());
    const apolloProvider = createMockApollo([[query, funnelHandler]]);

    wrapper = shallowMountExtended(AgenticAdoptionFunnelPanel, {
      apolloProvider,
      provide: { fullPath },
      propsData: {
        namespace,
        filters: mockGroupFilters,
        ...props,
      },
    });
  };

  const findPanel = () => wrapper.findComponent(ExtendedDashboardPanel);
  const findTimePeriodSelector = () => wrapper.findComponent(OverTimePeriodSelector);
  const findChart = () => wrapper.findComponent(AgenticAdoptionFunnelChart);
  const findEmptyState = () => wrapper.findByTestId('agentic-adoption-funnel-empty-state');

  beforeEach(() => {
    createComponent();
  });

  describe('component rendering', () => {
    it('renders the panel with the correct title', () => {
      expect(findPanel().props('title')).toBe('SAST triage and remediation funnel');
    });

    it('renders the time period selector', () => {
      expect(findTimePeriodSelector().exists()).toBe(true);
    });

    it('passes the fetched funnel data to the chart', async () => {
      await waitForPromises();

      expect(findChart().exists()).toBe(true);
      expect(findChart().props()).toMatchObject({
        namespace: 'group',
        detectedVulnerabilities: { count: 1240 },
        truePositives: { count: 870 },
        createdMergeRequests: { count: 287 },
        mergedMergeRequests: { count: 175 },
      });
    });
  });

  describe('Apollo query', () => {
    it('queries with the time period as a date range and the group filters', () => {
      expect(funnelHandler).toHaveBeenCalledWith({
        fullPath: mockGroupFullPath,
        projectId: mockGroupFilters.projectId,
        securityAttributesFilters: mockSecurityAttributesFilters,
        startDate: '2026-05-06',
        endDate: '2026-06-05',
      });
    });

    it('does not send reportType (the funnel is SAST-only)', () => {
      expect(funnelHandler).toHaveBeenCalledWith(
        expect.not.objectContaining({ reportType: expect.anything() }),
      );
    });

    it('refetches with an updated date range when the time period changes', async () => {
      await findTimePeriodSelector().vm.$emit('input', 90);
      await waitForPromises();

      expect(funnelHandler).toHaveBeenCalledWith(
        expect.objectContaining({
          startDate: '2026-03-07',
          endDate: '2026-06-05',
        }),
      );
    });
  });

  describe('time period URL sync', () => {
    it('initializes the time period from the URL parameter', () => {
      setWindowLocation('?vulnerabilityResolutionFunnel.timePeriod=60');
      createComponent();

      expect(findTimePeriodSelector().props('value')).toBe(60);
    });

    it('writes the time period to the URL when it changes', async () => {
      jest.spyOn(panelStateUrlSync, 'writeToUrl');

      await findTimePeriodSelector().vm.$emit('input', 90);

      expect(panelStateUrlSync.writeToUrl).toHaveBeenCalledWith({
        panelId: 'vulnerabilityResolutionFunnel',
        paramName: 'timePeriod',
        value: 90,
        defaultValue: 30,
      });
    });
  });

  describe('loading state', () => {
    it('shows loading state initially', () => {
      expect(findPanel().props('loading')).toBe(true);
    });

    it('hides loading state after data is loaded', async () => {
      await waitForPromises();

      expect(findPanel().props('loading')).toBe(false);
    });
  });

  describe('error handling', () => {
    it('shows the error state when the query fails', async () => {
      createComponent({ mockHandler: jest.fn().mockRejectedValue(new Error('GraphQL error')) });

      await waitForPromises();

      expect(findPanel().props('showAlertState')).toBe(true);
      expect(findChart().exists()).toBe(false);
      expect(findEmptyState().text()).toBe('Something went wrong. Please try again.');
    });

    it('resets the error state when a new fetch begins', async () => {
      createComponent({
        mockHandler: jest
          .fn()
          .mockRejectedValueOnce(new Error('GraphQL error'))
          .mockResolvedValue(serverResponse()),
      });

      await waitForPromises();
      expect(findEmptyState().text()).toBe('Something went wrong. Please try again.');

      await findTimePeriodSelector().vm.$emit('input', 90);
      await waitForPromises();

      expect(findEmptyState().exists()).toBe(false);
      expect(findPanel().props('showAlertState')).toBe(false);
    });
  });

  describe('when namespace is "project"', () => {
    const projectFilters = {
      trackedRefIds: ['gid://gitlab/Security::ProjectTrackedContext/1'],
      reportType: ['SAST'],
    };

    beforeEach(() => {
      createComponent({
        namespace: 'project',
        fullPath: mockProjectFullPath,
        query: projectVulnerabilityResolutionFunnel,
        props: { filters: projectFilters },
        mockHandler: jest
          .fn()
          .mockResolvedValue(serverResponse('Project', 'gid://gitlab/Project/1')),
      });
    });

    it('uses the project query with trackedRefIds and the date range', () => {
      expect(funnelHandler).toHaveBeenCalledWith({
        fullPath: mockProjectFullPath,
        trackedRefIds: projectFilters.trackedRefIds,
        startDate: '2026-05-06',
        endDate: '2026-06-05',
      });
    });

    it('does not send group-level filters (projectId, securityAttributesFilters)', () => {
      expect(funnelHandler).toHaveBeenCalledWith(
        expect.not.objectContaining({
          projectId: expect.anything(),
          securityAttributesFilters: expect.anything(),
        }),
      );
    });

    it('renders the funnel data from the project response', async () => {
      await waitForPromises();

      expect(findChart().exists()).toBe(true);
      expect(findChart().props('namespace')).toBe('project');
    });
  });

  describe('when namespace is "organization"', () => {
    const organizationFilters = {
      projectId: ['gid://gitlab/Project/123'],
      securityAttributesFilters: mockSecurityAttributesFilters,
      reportType: ['SAST'],
    };

    beforeEach(() => {
      createComponent({
        namespace: 'organization',
        fullPath: null,
        query: organizationVulnerabilityResolutionFunnel,
        props: { filters: organizationFilters },
        mockHandler: jest
          .fn()
          .mockResolvedValue(
            serverResponse('Organization', 'gid://gitlab/Organizations::Organization/1'),
          ),
      });
    });

    it('uses the organization query with projectId and the date range', () => {
      expect(funnelHandler).toHaveBeenCalledWith({
        fullPath: null,
        projectId: organizationFilters.projectId,
        startDate: '2026-05-06',
        endDate: '2026-06-05',
      });
    });

    it('does not send unsupported filters (securityAttributesFilters, reportType)', () => {
      expect(funnelHandler).toHaveBeenCalledWith(
        expect.not.objectContaining({
          securityAttributesFilters: expect.anything(),
          reportType: expect.anything(),
        }),
      );
    });

    it('renders the funnel data from the organization response', async () => {
      await waitForPromises();

      expect(findChart().exists()).toBe(true);
      expect(findChart().props('namespace')).toBe('organization');
    });
  });
});
