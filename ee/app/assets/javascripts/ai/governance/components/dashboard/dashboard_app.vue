<script>
import { s__, formatNumber, sprintf } from '~/locale';
import getAiGovernanceMetricsQuery from 'ee/ai/governance/graphql/queries/get_ai_governance_metrics.query.graphql';
import AuditTrailCard from './cards/audit_trail_card.vue';
import AgentInventoryCard from './cards/agent_inventory_card.vue';
import SummaryMetricTile from './summary_metric_tile.vue';

// Default timeframe for the summary KPIs. Matches the backend default
// (LAST_7_DAYS) in the aiGovernanceMetrics resolver (!244211).
const DEFAULT_TIMEFRAME = 'LAST_7_DAYS';

// Fallback trend used only when there is no series yet (feature flag off or no
// data). Keeps the sparklines from collapsing before real data arrives.
const FALLBACK_TREND = [
  [1, 0],
  [2, 0],
];

export default {
  name: 'AiGovernanceDashboardApp',
  components: {
    AuditTrailCard,
    AgentInventoryCard,
    SummaryMetricTile,
  },
  inject: {
    projectId: { default: null },
    groupFullPath: { default: null },
    projectFullPath: { default: null },
  },
  apollo: {
    metrics: {
      query: getAiGovernanceMetricsQuery,
      variables() {
        return {
          groupFullPath: this.groupFullPath || '',
          projectFullPath: this.projectFullPath || '',
          isProject: this.isProjectMode,
          timeframe: this.timeframe,
        };
      },
      update(data) {
        const namespace = this.isProjectMode ? data.project : data.group;
        return namespace?.aiGovernanceMetrics || null;
      },
    },
  },
  data() {
    return {
      metrics: null,
      // Single source of truth for the window. Fixed for now; point a duration
      // selector at this and the query + delta label follow automatically.
      timeframe: DEFAULT_TIMEFRAME,
    };
  },
  computed: {
    isProjectMode() {
      return Boolean(this.projectId);
    },
    summaryMetrics() {
      return [
        this.buildKpiTile('agents', s__('AiGovernance|AI agents'), this.metrics?.agents),
        this.buildKpiTile('sessions', s__('AiGovernance|AI sessions'), this.metrics?.sessions),
      ];
    },
  },
  methods: {
    // Signed change plus a period phrase for the selected timeframe, e.g.
    // "+9 this week". Extend the map when a duration selector is added.
    deltaLabel(diff) {
      const change = `${diff > 0 ? '+' : ''}${formatNumber(diff)}`;
      const templates = {
        LAST_24_HOURS: s__('AiGovernance|%{change} today'),
        LAST_7_DAYS: s__('AiGovernance|%{change} this week'),
        LAST_30_DAYS: s__('AiGovernance|%{change} this month'),
      };
      return sprintf(templates[this.timeframe] || templates.LAST_7_DAYS, { change });
    },
    buildKpiTile(key, label, kpi) {
      if (!kpi) {
        return { key, label, value: '—', chartData: FALLBACK_TREND };
      }

      const diff = kpi.count - kpi.previousCount;
      let deltaDirection = 'neutral';
      if (diff > 0) deltaDirection = 'up';
      else if (diff < 0) deltaDirection = 'down';

      const chartData = (kpi.trend || []).map((point, index) => [index + 1, point.count]);

      return {
        key,
        label,
        value: formatNumber(kpi.count),
        delta: diff === 0 ? '' : this.deltaLabel(diff),
        deltaDirection,
        chartData: chartData.length ? chartData : FALLBACK_TREND,
      };
    },
  },
};
</script>

<template>
  <div class="gl-mt-5">
    <div class="gl-mb-5 gl-grid gl-grid-cols-1 gl-gap-5 sm:gl-max-w-88 sm:gl-grid-cols-2">
      <summary-metric-tile
        v-for="metric in summaryMetrics"
        :key="metric.key"
        :data-testid="`summary-metric-${metric.key}`"
        :label="metric.label"
        :value="metric.value"
        :delta="metric.delta"
        :delta-direction="metric.deltaDirection"
        :chart-data="metric.chartData"
      />
    </div>

    <div class="gl-grid gl-grid-cols-1 gl-gap-5 md:gl-grid-cols-2">
      <audit-trail-card data-testid="dashboard-card-audit-trail" />
      <agent-inventory-card data-testid="dashboard-card-agent-inventory" />
    </div>
  </div>
</template>
