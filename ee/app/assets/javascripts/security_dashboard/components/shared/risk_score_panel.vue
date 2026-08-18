<script>
import { GlDashboardPanel, GlBadge, GlTooltipDirective } from '@gitlab/ui';
import { sprintf, s__, n__ } from '~/locale';
import { readFromUrl, writeToUrl } from 'ee/security_dashboard/utils/panel_state_url_sync';
import groupTotalRiskScore from 'ee/security_dashboard/graphql/queries/group_total_risk_score.query.graphql';
import organizationTotalRiskScore from 'ee/security_dashboard/graphql/queries/organization_total_risk_score.query.graphql';
import TotalRiskScore from './charts/total_risk_score.vue';
import RiskScoreByProject from './charts/risk_score_by_project.vue';
import RiskScoreGroupBy from './risk_score_group_by.vue';
import RiskScoreTooltip from './risk_score_tooltip.vue';

const PANEL_ID = 'riskScore';
const GROUP_BY_PARAM_NAME = 'groupBy';
const GROUP_BY_DEFAULT = 'default';
const GROUP_BY_PROJECT = 'project';

const NAMESPACE_CONFIG = {
  group: {
    query: groupTotalRiskScore,
    pageLevelFilters: ['projectId', 'securityAttributesFilters'],
  },
  organization: {
    query: organizationTotalRiskScore,
    pageLevelFilters: ['projectId'],
  },
};

export default {
  name: 'RiskScorePanel',
  components: {
    GlDashboardPanel,
    GlBadge,
    TotalRiskScore,
    RiskScoreByProject,
    RiskScoreGroupBy,
    RiskScoreTooltip,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  inject: { fullPath: { default: null } },
  props: {
    namespace: {
      type: String,
      required: true,
      validator: (value) => Object.keys(NAMESPACE_CONFIG).includes(value),
    },
    filters: {
      type: Object,
      required: true,
    },
  },
  data() {
    const groupedBy = readFromUrl({
      panelId: PANEL_ID,
      paramName: GROUP_BY_PARAM_NAME,
      defaultValue: GROUP_BY_DEFAULT,
    });
    return {
      riskScore: 0,
      projects: [],
      hasFetchError: false,
      groupedBy,
      projectCount: 0,
    };
  },
  apollo: {
    riskScore: {
      query() {
        return this.config.query;
      },
      variables() {
        return {
          fullPath: this.fullPath,
          includeByDefault: this.groupedBy === GROUP_BY_DEFAULT,
          includeByProject: this.groupedBy === GROUP_BY_PROJECT,
          first: this.$options.projectCountThreshold,
          ...this.queryVariables,
        };
      },
      update(data) {
        return data?.namespace?.securityMetrics?.riskScore?.score || 0;
      },
      result({ data }) {
        const { riskScore } = data?.namespace?.securityMetrics || {};
        const { byProject } = riskScore || {};

        const projectNodes = [...(byProject?.nodes || [])];
        projectNodes.sort((a, b) => b.score - a.score);
        this.projects = projectNodes;

        this.projectCount = riskScore?.projectCount;
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
  computed: {
    config() {
      return NAMESPACE_CONFIG[this.namespace];
    },
    queryVariables() {
      return this.config.pageLevelFilters.reduce((acc, key) => {
        if (this.filters[key] !== undefined) {
          acc[key] = this.filters[key];
        }
        return acc;
      }, {});
    },
    projectsNotShown() {
      return Math.max(0, this.projectCount - this.$options.projectCountThreshold);
    },
    showProjectsNotShownBadge() {
      return this.groupedBy === GROUP_BY_PROJECT && this.projectsNotShown > 0;
    },
    projectsNotShownLabel() {
      return sprintf(
        n__(
          'SecurityReports|%{count} project not shown',
          'SecurityReports|%{count} projects not shown',
          this.projectsNotShown,
        ),
        { count: this.projectsNotShown },
      );
    },
    maxProjectsTooltipTitle() {
      return sprintf(
        s__(
          'SecurityReports|Only the top %{count} projects with the highest risk scores are shown. Use the filter at the top of the dashboard to narrow down your results.',
        ),
        { count: this.$options.projectCountThreshold },
      );
    },
  },
  watch: {
    groupedBy(value) {
      writeToUrl({
        panelId: PANEL_ID,
        paramName: GROUP_BY_PARAM_NAME,
        value,
        defaultValue: GROUP_BY_DEFAULT,
      });
    },
  },
  projectCountThreshold: 96,
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
    <template #filters>
      <gl-badge
        v-if="showProjectsNotShownBadge"
        v-gl-tooltip
        variant="neutral"
        class="gl-mr-3"
        :title="maxProjectsTooltipTitle"
      >
        {{ projectsNotShownLabel }}
      </gl-badge>
      <risk-score-group-by v-model="groupedBy" />
    </template>
    <template #body>
      <template v-if="hasFetchError">
        <p class="gl-m-0 gl-flex gl-h-full gl-w-full gl-items-center gl-justify-center gl-p-0">
          {{ __('Something went wrong. Please try again.') }}
        </p>
      </template>
      <template v-else>
        <total-risk-score v-if="groupedBy === 'default'" :score="riskScore" />
        <risk-score-by-project v-else :risk-scores="projects" class="gl-pt-3" />
      </template>
    </template>
  </gl-dashboard-panel>
</template>
