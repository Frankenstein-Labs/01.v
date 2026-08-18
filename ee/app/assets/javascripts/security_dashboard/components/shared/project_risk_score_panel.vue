<script>
import { GlDashboardPanel } from '@gitlab/ui';
import projectTotalRiskScore from 'ee/security_dashboard/graphql/queries/project_total_risk_score.query.graphql';
import TotalRiskScore from './charts/total_risk_score.vue';
import RiskScoreTooltip from './risk_score_tooltip.vue';

export default {
  name: 'ProjectRiskScorePanel',
  components: {
    GlDashboardPanel,
    TotalRiskScore,
    RiskScoreTooltip,
  },
  inject: ['projectFullPath'],
  props: {
    filters: {
      type: Object,
      required: true,
    },
  },
  data() {
    return {
      riskScore: 0,
      hasFetchError: false,
    };
  },
  apollo: {
    riskScore: {
      query: projectTotalRiskScore,
      context: {
        featureCategory: 'vulnerability_management',
      },
      variables() {
        return {
          fullPath: this.projectFullPath,
          trackedRefIds: this.filters.trackedRefIds,
        };
      },
      update(data) {
        return data?.project?.securityMetrics?.riskScore?.score || 0;
      },
      result({ data }) {
        if (data?.project?.securityMetrics?.riskScore?.score !== undefined) {
          this.hasFetchError = false;
        }
      },
      error() {
        this.hasFetchError = true;
      },
      watchLoading(isLoading) {
        if (isLoading) {
          this.hasFetchError = false;
        }
      },
    },
  },
};
</script>

<template>
  <gl-dashboard-panel
    :title="s__('SecurityReports|Risk score')"
    :loading="$apollo.queries.riskScore.loading"
    :border-color-class="hasFetchError ? 'gl-border-t-red-500' : ''"
    :title-icon="hasFetchError ? 'error' : ''"
    :title-icon-class="hasFetchError ? 'gl-text-danger' : ''"
    :title-popover-classes="['gl-min-w-fit']"
  >
    <template #info-popover-title>{{ s__('SecurityReports|Risk score formula') }}</template>
    <template #info-popover-content>
      <risk-score-tooltip />
    </template>
    <template #body>
      <template v-if="hasFetchError">
        <p class="gl-m-0 gl-flex gl-h-full gl-w-full gl-items-center gl-justify-center gl-p-0">
          {{ __('Something went wrong. Please try again.') }}
        </p>
      </template>
      <template v-else>
        <total-risk-score :score="riskScore" />
      </template>
    </template>
  </gl-dashboard-panel>
</template>
