import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { merge } from 'lodash-es';
import { GlDashboardPanel, GlBadge } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import setWindowLocation from 'helpers/set_window_location_helper';
import * as panelStateUrlSync from 'ee/security_dashboard/utils/panel_state_url_sync';
import RiskScorePanel from 'ee/security_dashboard/components/shared/risk_score_panel.vue';
import TotalRiskScore from 'ee/security_dashboard/components/shared/charts/total_risk_score.vue';
import RiskScoreByProject from 'ee/security_dashboard/components/shared/charts/risk_score_by_project.vue';
import RiskScoreGroupBy from 'ee/security_dashboard/components/shared/risk_score_group_by.vue';
import RiskScoreTooltip from 'ee/security_dashboard/components/shared/risk_score_tooltip.vue';
import groupTotalRiskScore from 'ee/security_dashboard/graphql/queries/group_total_risk_score.query.graphql';
import organizationTotalRiskScore from 'ee/security_dashboard/graphql/queries/organization_total_risk_score.query.graphql';
import { mockSecurityAttributesFilters } from '../mock_data';

Vue.use(VueApollo);

describe('RiskScorePanel', () => {
  let wrapper;
  let riskScoreHandler;

  const mockGroupFullPath = 'group/subgroup';
  const mockFilters = {
    projectId: 'gid://gitlab/Project/123',
    securityAttributesFilters: mockSecurityAttributesFilters,
  };
  const defaultRiskScore = 50;
  const defaultByProjectMockData = [
    {
      rating: 'CRITICAL',
      score: 85.5,
      project: {
        id: 1,
        name: 'Project A',
        fullPath: 'group-a/project-a',
      },
    },
    {
      rating: 'HIGH',
      score: 70.1,
      project: {
        id: 2,
        name: 'Project B',
        fullPath: 'group-a/project-b',
      },
    },
  ];
  const defaultMockRiskScoreData = {
    data: {
      namespace: {
        id: 'gid://gitlab/Group/1',
        securityMetrics: {
          riskScore: {
            score: defaultRiskScore,
            projectCount: 50,
            byProject: {
              nodes: defaultByProjectMockData,
            },
          },
        },
      },
    },
  };

  const createMockData = ({ overrides = {} } = {}) =>
    merge({}, defaultMockRiskScoreData, overrides);

  const createComponent = ({
    props = {},
    namespace = 'group',
    query = groupTotalRiskScore,
    fullPath = mockGroupFullPath,
    mockRiskScoreHandler = null,
  } = {}) => {
    riskScoreHandler = mockRiskScoreHandler || jest.fn().mockResolvedValue(createMockData());

    const apolloProvider = createMockApollo([[query, riskScoreHandler]]);

    wrapper = shallowMountExtended(RiskScorePanel, {
      apolloProvider,
      propsData: {
        namespace,
        filters: mockFilters,
        ...props,
      },
      provide: {
        fullPath,
      },
    });
  };

  const findDashboardPanel = () => wrapper.findComponent(GlDashboardPanel);
  const findTotalRiskScore = () => wrapper.findComponent(TotalRiskScore);
  const findRiskScoreByProject = () => wrapper.findComponent(RiskScoreByProject);
  const findRiskScoreGroupBy = () => wrapper.findComponent(RiskScoreGroupBy);
  const findRiskScoreTooltip = () => wrapper.findComponent(RiskScoreTooltip);
  const findProjectsNotShownBadge = () => wrapper.findComponent(GlBadge);
  const findBodyMessage = () => wrapper.find('p');

  const clickToggleButtonBy = async (value) => {
    await findRiskScoreGroupBy().vm.$emit('input', value);
    await waitForPromises();
  };

  beforeEach(() => {
    createComponent();
  });

  afterEach(() => {
    setWindowLocation('');
  });

  describe('component rendering', () => {
    it('sets the correct title for the dashboard panel', () => {
      expect(findDashboardPanel().props('title')).toBe('Risk score');
    });

    it('passes the fetched score to the TotalRiskScore component', async () => {
      expect(findTotalRiskScore().props('score')).toBe(0);

      await waitForPromises();

      expect(findTotalRiskScore().props('score')).toBe(defaultRiskScore);
    });

    it('passes loading state to the dashboard panel', async () => {
      expect(findDashboardPanel().props('loading')).toBe(true);

      await waitForPromises();

      expect(findDashboardPanel().props('loading')).toBe(false);
    });

    it('passes the projects to the risk score by project component', async () => {
      await clickToggleButtonBy('project');

      expect(findRiskScoreByProject().props('riskScores')).toMatchObject(defaultByProjectMockData);
    });

    it('renders the risk score tooltip', () => {
      expect(findRiskScoreTooltip().exists()).toBe(true);
    });
  });

  describe('group by functionality', () => {
    beforeEach(() => {
      createComponent();
    });

    it('switches to project grouping when project button is clicked', async () => {
      await waitForPromises();
      await clickToggleButtonBy('project');

      expect(findRiskScoreGroupBy().props('value')).toBe('project');
    });

    it('switches back to "No grouping" grouping when no grouping button is clicked', async () => {
      await waitForPromises();
      await clickToggleButtonBy('project');
      await clickToggleButtonBy('default');

      expect(findRiskScoreGroupBy().props('value')).toBe('default');
    });

    it('initializes with project grouping if URL parameter is set', () => {
      setWindowLocation('?riskScore.groupBy=project');
      createComponent();

      expect(findRiskScoreGroupBy().props('value')).toBe('project');
    });

    it('calls writeToUrl when grouping is set to project', async () => {
      jest.spyOn(panelStateUrlSync, 'writeToUrl');

      await clickToggleButtonBy('project');

      expect(panelStateUrlSync.writeToUrl).toHaveBeenCalledWith({
        panelId: 'riskScore',
        paramName: 'groupBy',
        value: 'project',
        defaultValue: 'default',
      });
    });
  });

  describe('Apollo query', () => {
    it('fetches total risk score when component is created', () => {
      expect(riskScoreHandler).toHaveBeenCalledWith({
        fullPath: mockGroupFullPath,
        projectId: mockFilters.projectId,
        securityAttributesFilters: mockSecurityAttributesFilters,
        includeByDefault: true,
        includeByProject: false,
        first: 96,
      });
    });

    it('passes supported filters to the GraphQL query', () => {
      createComponent({
        props: {
          filters: {
            projectId: ['gid://gitlab/Project/99'],
          },
        },
      });

      expect(riskScoreHandler).toHaveBeenCalledWith(
        expect.objectContaining({
          fullPath: mockGroupFullPath,
          projectId: ['gid://gitlab/Project/99'],
          first: 96,
        }),
      );
    });

    it('does not add unsupported filters to the GraphQL query', () => {
      const unsupportedFilter = ['filterValue'];

      createComponent({
        props: {
          filters: { unsupportedFilter },
        },
      });

      expect(riskScoreHandler).not.toHaveBeenCalledWith(
        expect.objectContaining({
          unsupportedFilter,
        }),
      );
    });

    it('updates query variables when switching to report type grouping', async () => {
      await findRiskScoreGroupBy().vm.$emit('input', 'project');
      await waitForPromises();

      expect(riskScoreHandler).toHaveBeenCalledWith(
        expect.objectContaining({
          includeByDefault: false,
          includeByProject: true,
          first: 96,
        }),
      );
    });
  });

  describe('when namespace is "organization"', () => {
    const organizationFilters = {
      projectId: ['gid://gitlab/Project/123'],
      securityAttributesFilters: mockSecurityAttributesFilters,
    };

    beforeEach(() => {
      createComponent({
        namespace: 'organization',
        query: organizationTotalRiskScore,
        fullPath: null,
        props: { filters: organizationFilters },
      });
    });

    it('uses the organization query without a fullPath or attribute filters', () => {
      expect(riskScoreHandler).toHaveBeenCalledWith({
        fullPath: null,
        projectId: organizationFilters.projectId,
        includeByDefault: true,
        includeByProject: false,
        first: 96,
      });

      const [variables] = riskScoreHandler.mock.calls[0];
      expect(variables).not.toHaveProperty('securityAttributesFilters');
    });

    it('renders the fetched score from the namespace response', async () => {
      await waitForPromises();

      expect(findTotalRiskScore().props('score')).toBe(defaultRiskScore);
    });
  });

  describe('projects not shown badge', () => {
    const createMockDataWithProjectCount = ({ projectCount } = {}) =>
      createMockData({
        overrides: {
          data: {
            namespace: {
              securityMetrics: {
                riskScore: {
                  projectCount,
                },
              },
            },
          },
        },
      });

    describe('when groupedBy is "default"', () => {
      it('does not show the badge when projectCount higher than threshold', async () => {
        createComponent({
          mockRiskScoreHandler: jest
            .fn()
            .mockResolvedValue(createMockDataWithProjectCount({ projectCount: 100 })),
        });

        await waitForPromises();

        expect(findProjectsNotShownBadge().exists()).toBe(false);
      });
    });

    describe('when groupedBy is "project"', () => {
      it.each`
        projectCount | shouldShow | label
        ${95}        | ${false}   | ${''}
        ${96}        | ${false}   | ${''}
        ${97}        | ${true}    | ${'1 project not shown'}
        ${98}        | ${true}    | ${'2 projects not shown'}
      `(
        'when projectCount is "$projectCount", it should show the badge: "$shouldShow" with correct label',
        async ({ projectCount, shouldShow, label }) => {
          createComponent({
            mockRiskScoreHandler: jest
              .fn()
              .mockResolvedValue(createMockDataWithProjectCount({ projectCount })),
          });

          await findRiskScoreGroupBy().vm.$emit('input', 'project');
          await waitForPromises();

          expect(findProjectsNotShownBadge().exists()).toBe(shouldShow);
          if (shouldShow) {
            expect(findProjectsNotShownBadge().text()).toBe(label);
          }
        },
      );
    });

    describe('badge properties', () => {
      beforeEach(async () => {
        createComponent({
          mockRiskScoreHandler: jest
            .fn()
            .mockResolvedValue(createMockDataWithProjectCount({ projectCount: 100 })),
        });

        await findRiskScoreGroupBy().vm.$emit('input', 'project');
        await waitForPromises();
      });

      it('has the correct variant', () => {
        expect(findProjectsNotShownBadge().props('variant')).toBe('neutral');
      });

      it('has the correct tooltip with dynamic threshold', () => {
        const expectedTooltip =
          'Only the top 96 projects with the highest risk scores are shown. Use the filter at the top of the dashboard to narrow down your results.';
        expect(findProjectsNotShownBadge().attributes('title')).toBe(expectedTooltip);
      });
    });
  });

  describe('error handling', () => {
    describe.each`
      errorType                   | mockRiskScoreHandler
      ${'GraphQL query failures'} | ${jest.fn().mockRejectedValue(new Error('GraphQL query failed'))}
      ${'server error responses'} | ${jest.fn().mockResolvedValue({ errors: [{ message: 'Internal server error' }] })}
    `('$errorType', ({ mockRiskScoreHandler }) => {
      beforeEach(async () => {
        createComponent({
          mockRiskScoreHandler,
        });

        await waitForPromises();
      });

      it('sets the dashboard panel to alert state', () => {
        expect(findDashboardPanel().props()).toMatchObject({
          borderColorClass: 'gl-border-t-red-500',
          titleIcon: 'error',
          titleIconClass: 'gl-text-danger',
        });
      });

      it('shows the correct error message', () => {
        expect(findBodyMessage().text()).toBe('Something went wrong. Please try again.');
      });
    });

    it('resets hasFetchError when a new fetch begins', async () => {
      const mockRiskScoreHandler = jest
        .fn()
        .mockRejectedValueOnce(new Error('GraphQL query failed'))
        .mockResolvedValue(createMockData());

      createComponent({ mockRiskScoreHandler });

      await waitForPromises();

      expect(findBodyMessage().text()).toBe('Something went wrong. Please try again.');

      await clickToggleButtonBy('project');

      expect(findBodyMessage().exists()).toBe(false);
    });
  });
});
