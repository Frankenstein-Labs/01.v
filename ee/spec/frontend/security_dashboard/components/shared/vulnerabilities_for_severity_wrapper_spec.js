import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { setActivePinia, createPinia } from 'pinia';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import VulnerabilitiesForSeverityPanel from 'ee/security_dashboard/components/shared/charts/vulnerabilities_for_severity_panel.vue';
import VulnerabilitiesForSeverityWrapper from 'ee/security_dashboard/components/shared/vulnerabilities_for_severity_wrapper.vue';
import groupVulnerabilitiesPerSeverity from 'ee/security_dashboard/graphql/queries/group_vulnerabilities_per_severity.query.graphql';
import projectVulnerabilitiesPerSeverity from 'ee/security_dashboard/graphql/queries/project_vulnerabilities_per_severity.query.graphql';
import organizationVulnerabilitiesPerSeverity from 'ee/security_dashboard/graphql/queries/organization_vulnerabilities_per_severity.query.graphql';
import { useChartExportStore } from 'ee/security_dashboard/stores/chart_export_store';
import { getSeverityColors } from 'ee/security_dashboard/utils/chart_utils';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { mockSecurityAttributesFilters } from '../mock_data';

jest.mock('ee/security_dashboard/utils/chart_utils', () => ({
  getSeverityColors: jest.fn(),
}));

Vue.use(VueApollo);
jest.mock('~/alert');

describe('VulnerabilitiesForSeverityWrapper', () => {
  let wrapper;
  let vulnerabilitiesPerSeverityHandler;

  beforeEach(() => {
    setActivePinia(createPinia());

    getSeverityColors.mockReturnValue({
      critical: '#660e00',
      high: '#ae1800',
      medium: '#9e5400',
      low: '#c17d10',
      info: '#428fdc',
      unknown: '#868686',
    });
  });

  const securityMetrics = {
    vulnerabilitiesPerSeverity: {
      critical: { count: 3, medianAge: 10.5, __typename: 'VulnerabilitySeverityCount' },
      high: { count: 5, medianAge: 11.5, __typename: 'VulnerabilitySeverityCount' },
      medium: { count: 8, medianAge: 12.5, __typename: 'VulnerabilitySeverityCount' },
      low: { count: 10, medianAge: 80.1, __typename: 'VulnerabilitySeverityCount' },
      unknown: { count: 5, medianAge: 56.1, __typename: 'VulnerabilitySeverityCount' },
      info: { count: 3, medianAge: 3.1, __typename: 'VulnerabilitySeverityCount' },
      __typename: 'VulnerabilitiesPerSeverity',
    },
    __typename: 'SecurityMetrics',
  };

  const namespaceConfigs = {
    project: {
      namespace: 'project',
      fullPath: 'project-1',
      query: projectVulnerabilitiesPerSeverity,
      filters: {
        reportType: ['API_FUZZING'],
        trackedRefIds: ['gid://gitlab/Security::ProjectTrackedContext/1'],
      },
      expectedVariables: {
        fullPath: 'project-1',
        reportType: ['API_FUZZING'],
        trackedRefIds: ['gid://gitlab/Security::ProjectTrackedContext/1'],
      },
      createMockData: () => ({
        data: {
          namespace: {
            id: 'gid://gitlab/Project/1',
            securityMetrics,
            __typename: 'Project',
          },
        },
      }),
    },
    group: {
      namespace: 'group',
      fullPath: 'group/subgroup',
      query: groupVulnerabilitiesPerSeverity,
      filters: {
        projectId: 'gid://gitlab/Project/123',
        reportType: ['SAST'],
        securityAttributesFilters: mockSecurityAttributesFilters,
      },
      expectedVariables: {
        fullPath: 'group/subgroup',
        projectId: 'gid://gitlab/Project/123',
        reportType: ['SAST'],
        securityAttributesFilters: mockSecurityAttributesFilters,
      },
      createMockData: () => ({
        data: {
          namespace: {
            id: 'gid://gitlab/Group/1',
            securityMetrics,
            __typename: 'Group',
          },
        },
      }),
    },
    organization: {
      namespace: 'organization',
      fullPath: null,
      query: organizationVulnerabilitiesPerSeverity,
      filters: {
        projectId: 'gid://gitlab/Project/123',
        reportType: ['SAST'],
      },
      expectedVariables: {
        fullPath: null,
        projectId: 'gid://gitlab/Project/123',
        reportType: ['SAST'],
      },
      createMockData: () => ({
        data: {
          namespace: {
            id: 'gid://gitlab/Organizations::Organization/1',
            securityMetrics,
            __typename: 'Organization',
          },
        },
      }),
    },
  };

  const createComponent = ({
    namespace = 'project',
    props = {},
    mockVulnerabilitiesPerSeverityHandler = null,
  } = {}) => {
    const config = namespaceConfigs[namespace];
    const defaultMockData = config.createMockData();
    vulnerabilitiesPerSeverityHandler =
      mockVulnerabilitiesPerSeverityHandler || jest.fn().mockResolvedValue(defaultMockData);

    const apolloProvider = createMockApollo([[config.query, vulnerabilitiesPerSeverityHandler]]);

    wrapper = shallowMountExtended(VulnerabilitiesForSeverityWrapper, {
      apolloProvider,
      propsData: {
        namespace: config.namespace,
        filters: config.filters,
        severity: 'medium',
        ...props,
      },
      provide: {
        fullPath: config.fullPath,
        securityVulnerabilitiesPath: '/group/security/vulnerabilities',
      },
    });

    return { config };
  };

  const findVulnerabilitiesForSeverityPanel = () =>
    wrapper.findComponent(VulnerabilitiesForSeverityPanel);

  describe('component rendering', () => {
    it('renders the vulnerabilities for severity panel', () => {
      createComponent();
      expect(findVulnerabilitiesForSeverityPanel().exists()).toBe(true);
    });

    it('passes the severity to the panel', () => {
      createComponent();
      expect(findVulnerabilitiesForSeverityPanel().props('severity')).toBe('medium');
    });

    it('passes the filters to the panel', () => {
      const { config } = createComponent();
      expect(findVulnerabilitiesForSeverityPanel().props('filters')).toBe(config.filters);
    });

    it('passes the count and medianAge based on the data', async () => {
      const { config } = createComponent();
      const { medium } =
        config.createMockData().data.namespace.securityMetrics.vulnerabilitiesPerSeverity;
      await waitForPromises();

      expect(findVulnerabilitiesForSeverityPanel().props('count')).toBe(medium.count);
      expect(findVulnerabilitiesForSeverityPanel().props('medianAge')).toBe(medium.medianAge);
    });

    it('passes loading state to panels base', async () => {
      createComponent();
      expect(findVulnerabilitiesForSeverityPanel().props('loading')).toBe(true);

      await waitForPromises();

      expect(findVulnerabilitiesForSeverityPanel().props('loading')).toBe(false);
    });
  });

  describe('Apollo query', () => {
    it('fetches vulnerabilities per severity data when component is created', () => {
      const { config } = createComponent();
      expect(vulnerabilitiesPerSeverityHandler).toHaveBeenCalledWith(config.expectedVariables);
    });

    describe.each(['project', 'group', 'organization'])('when namespace is "%s"', (namespace) => {
      it('vulnerabilities per severity data when component is created', async () => {
        const { config } = createComponent({ namespace });
        await waitForPromises();

        expect(vulnerabilitiesPerSeverityHandler).toHaveBeenCalledWith({
          ...config.expectedVariables,
        });
      });
    });

    it('does not add unsupported filters that are passed', () => {
      const unsupportedFilter = ['filterValue'];
      createComponent({
        props: {
          filters: { unsupportedFilter },
        },
      });

      expect(vulnerabilitiesPerSeverityHandler).not.toHaveBeenCalledWith(
        expect.objectContaining({
          unsupportedFilter,
        }),
      );
    });
  });

  describe('error handling', () => {
    describe.each`
      errorType                   | mockVulnerabilitiesPerSeverityHandler
      ${'GraphQL query failures'} | ${jest.fn().mockRejectedValue(new Error('GraphQL query failed'))}
      ${'server error responses'} | ${jest.fn().mockResolvedValue({ errors: [{ message: 'Internal server error' }] })}
    `('$errorType', ({ mockVulnerabilitiesPerSeverityHandler }) => {
      beforeEach(async () => {
        createComponent({
          mockVulnerabilitiesPerSeverityHandler,
        });

        await waitForPromises();
      });

      it('sets the panel error prop', () => {
        expect(findVulnerabilitiesForSeverityPanel().props('error')).toBe(true);
      });
    });

    it('resets hasFetchError when a new fetch begins', async () => {
      const mockVulnerabilitiesPerSeverityHandler = jest
        .fn()
        .mockRejectedValueOnce(new Error('GraphQL query failed'))
        .mockResolvedValue(namespaceConfigs.project.createMockData());

      createComponent({ mockVulnerabilitiesPerSeverityHandler });

      await waitForPromises();

      expect(findVulnerabilitiesForSeverityPanel().props('error')).toBe(true);

      await wrapper.setProps({ filters: { reportType: ['SAST'] } });
      await waitForPromises();

      expect(findVulnerabilitiesForSeverityPanel().props('error')).toBe(false);
    });
  });

  describe('chart export store integration', () => {
    it('registers with the chart export store on mount under the shared group key', () => {
      createComponent({ props: { severity: 'critical' } });

      const store = useChartExportStore();
      expect(store.nestedExporters.vulnerabilities_by_severity_count).toHaveProperty('critical');
    });

    it('unregisters from the chart export store on destroy', () => {
      createComponent({ props: { severity: 'high' } });

      const store = useChartExportStore();
      expect(store.nestedExporters.vulnerabilities_by_severity_count).toHaveProperty('high');

      wrapper.destroy();

      expect(store.nestedExporters.vulnerabilities_by_severity_count).toBeUndefined();
    });

    it('the registered function returns the vulnerabilitySeverity data including color', async () => {
      getSeverityColors.mockReturnValue({ medium: '#9e5400' });

      const { config } = createComponent({ props: { severity: 'medium' } });
      await waitForPromises();

      const store = useChartExportStore();
      const exportFn = store.nestedExporters.vulnerabilities_by_severity_count.medium;
      const result = exportFn();

      const { medium } =
        config.createMockData().data.namespace.securityMetrics.vulnerabilitiesPerSeverity;
      expect(result).toMatchObject({
        count: medium.count,
        medianAge: medium.medianAge,
        color: '#9e5400',
      });
    });
  });
});
