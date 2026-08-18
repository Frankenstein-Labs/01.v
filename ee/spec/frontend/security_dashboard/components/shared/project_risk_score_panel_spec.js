import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { merge } from 'lodash-es';
import { GlDashboardPanel } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import ProjectRiskScorePanel from 'ee/security_dashboard/components/shared/project_risk_score_panel.vue';
import TotalRiskScore from 'ee/security_dashboard/components/shared/charts/total_risk_score.vue';
import RiskScoreTooltip from 'ee/security_dashboard/components/shared/risk_score_tooltip.vue';
import projectTotalRiskScore from 'ee/security_dashboard/graphql/queries/project_total_risk_score.query.graphql';

Vue.use(VueApollo);

describe('ProjectRiskScorePanel', () => {
  let wrapper;
  let riskScoreHandler;

  const mockProjectFullPath = 'namespace/project';
  const defaultRiskScore = 50;
  const defaultMockRiskScoreData = {
    data: {
      project: {
        id: 'gid://gitlab/Project/1',
        securityMetrics: {
          riskScore: {
            score: defaultRiskScore,
          },
        },
      },
    },
  };

  const createMockData = ({ overrides = {} } = {}) =>
    merge({}, defaultMockRiskScoreData, overrides);

  const createComponent = ({ mockRiskScoreHandler = null, props = {} } = {}) => {
    riskScoreHandler = mockRiskScoreHandler || jest.fn().mockResolvedValue(createMockData());

    const apolloProvider = createMockApollo([[projectTotalRiskScore, riskScoreHandler]]);

    wrapper = shallowMountExtended(ProjectRiskScorePanel, {
      apolloProvider,
      propsData: { filters: {}, ...props },
      provide: {
        projectFullPath: mockProjectFullPath,
      },
    });
  };

  const findDashboardPanel = () => wrapper.findComponent(GlDashboardPanel);
  const findTotalRiskScore = () => wrapper.findComponent(TotalRiskScore);
  const findRiskScoreTooltip = () => wrapper.findComponent(RiskScoreTooltip);
  const findBodyMessage = () => wrapper.find('p');

  beforeEach(() => {
    createComponent();
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

    it('renders the risk score tooltip', () => {
      expect(findRiskScoreTooltip().exists()).toBe(true);
    });
  });

  describe('Apollo query', () => {
    it('fetches total risk score when component is created', () => {
      expect(riskScoreHandler).toHaveBeenCalledWith({
        fullPath: mockProjectFullPath,
      });
    });

    it('passes trackedRefIds from filters when provided', () => {
      const trackedRefIds = ['gid://gitlab/Security::ProjectTrackedContext/2'];
      createComponent({ props: { filters: { trackedRefIds } } });

      expect(riskScoreHandler).toHaveBeenCalledWith({
        fullPath: mockProjectFullPath,
        trackedRefIds,
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
  });
});
