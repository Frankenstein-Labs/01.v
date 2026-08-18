import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import waitForPromises from 'helpers/wait_for_promises';
import createMockApollo from 'helpers/mock_apollo_helper';
import AiGovernanceDashboardApp from 'ee/ai/governance/components/dashboard/dashboard_app.vue';
import AuditTrailCard from 'ee/ai/governance/components/dashboard/cards/audit_trail_card.vue';
import AgentInventoryCard from 'ee/ai/governance/components/dashboard/cards/agent_inventory_card.vue';
import getAiGovernanceMetricsQuery from 'ee/ai/governance/graphql/queries/get_ai_governance_metrics.query.graphql';

Vue.use(VueApollo);

const GROUP_FULL_PATH = 'gitlab-org';

const kpi = (count, previousCount, counts) => ({
  count,
  previousCount,
  trend: counts.map((c, i) => ({ bucketStart: `2026-07-2${i}T00:00:00Z`, count: c })),
});

const metricsResponse = {
  data: {
    group: {
      id: 'gid://gitlab/Group/1',
      aiGovernanceMetrics: {
        agents: kpi(12, 8, [8, 10, 12]),
        sessions: kpi(40, 55, [55, 48, 40]),
      },
    },
  },
};

describe('AiGovernanceDashboardApp', () => {
  let wrapper;

  const createComponent = ({ handler = jest.fn().mockResolvedValue(metricsResponse) } = {}) => {
    const apolloProvider = createMockApollo([[getAiGovernanceMetricsQuery, handler]]);

    wrapper = shallowMountExtended(AiGovernanceDashboardApp, {
      apolloProvider,
      provide: { groupFullPath: GROUP_FULL_PATH, projectFullPath: '', projectId: null },
    });
  };

  const findSummaryMetric = (key) => wrapper.findComponentByTestId(`summary-metric-${key}`);
  const findCard = (key) => wrapper.findByTestId(`dashboard-card-${key}`);

  describe('summary header', () => {
    beforeEach(() => createComponent());

    it.each(['agents', 'sessions'])('renders the %s summary metric', (key) => {
      expect(findSummaryMetric(key).exists()).toBe(true);
    });

    it('does not render a compliance posture tile', () => {
      expect(findSummaryMetric('posture').exists()).toBe(false);
    });
  });

  describe('metrics wiring', () => {
    it('requests group metrics with the default timeframe', async () => {
      const handler = jest.fn().mockResolvedValue(metricsResponse);
      createComponent({ handler });
      await waitForPromises();

      expect(handler).toHaveBeenCalledWith(
        expect.objectContaining({
          groupFullPath: GROUP_FULL_PATH,
          isProject: false,
          timeframe: 'LAST_7_DAYS',
        }),
      );
    });

    it('maps a rising KPI to an up delta and a trend sparkline', async () => {
      createComponent();
      await waitForPromises();

      const agents = findSummaryMetric('agents');
      expect(agents.props('value')).toBe('12');
      expect(agents.props('delta')).toBe('+4 this week');
      expect(agents.props('deltaDirection')).toBe('up');
      expect(agents.props('chartData')).toEqual([
        [1, 8],
        [2, 10],
        [3, 12],
      ]);
    });

    it('maps a falling KPI to a down delta', async () => {
      createComponent();
      await waitForPromises();

      const sessions = findSummaryMetric('sessions');
      expect(sessions.props('value')).toBe('40');
      expect(sessions.props('delta')).toBe('-15 this week');
      expect(sessions.props('deltaDirection')).toBe('down');
    });

    it('falls back to a neutral placeholder when metrics are unavailable', async () => {
      const nullResponse = {
        data: { group: { id: 'gid://gitlab/Group/1', aiGovernanceMetrics: null } },
      };
      createComponent({ handler: jest.fn().mockResolvedValue(nullResponse) });
      await waitForPromises();

      const agents = findSummaryMetric('agents');
      expect(agents.props('value')).toBe('—');
    });
  });

  describe('data-backed cards', () => {
    beforeEach(() => createComponent());

    it('renders the Audit trail card', () => {
      expect(wrapper.findComponent(AuditTrailCard).exists()).toBe(true);
      expect(findCard('audit-trail').exists()).toBe(true);
    });

    it('renders the AI agent inventory card', () => {
      expect(wrapper.findComponent(AgentInventoryCard).exists()).toBe(true);
      expect(findCard('agent-inventory').exists()).toBe(true);
    });
  });
});
