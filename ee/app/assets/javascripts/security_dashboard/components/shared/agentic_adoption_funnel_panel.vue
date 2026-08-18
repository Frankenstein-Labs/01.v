<script>
import ExtendedDashboardPanel from '~/vue_shared/components/customizable_dashboard/extended_dashboard_panel.vue';
import { formatDate, getDateInPast } from '~/lib/utils/datetime_utility';
import groupVulnerabilityResolutionFunnel from 'ee/security_dashboard/graphql/queries/group_vulnerability_resolution_funnel.query.graphql';
import projectVulnerabilityResolutionFunnel from 'ee/security_dashboard/graphql/queries/project_vulnerability_resolution_funnel.query.graphql';
import organizationVulnerabilityResolutionFunnel from 'ee/security_dashboard/graphql/queries/organization_vulnerability_resolution_funnel.query.graphql';
import { readFromUrl, writeToUrl } from 'ee/security_dashboard/utils/panel_state_url_sync';
import AgenticAdoptionFunnelChart from './charts/agentic_adoption_funnel_chart.vue';
import OverTimePeriodSelector from './over_time_period_selector.vue';

const PANEL_ID = 'vulnerabilityResolutionFunnel';
const TIME_PERIOD_DEFAULT = 30;

const NAMESPACE_CONFIG = {
  project: {
    query: projectVulnerabilityResolutionFunnel,
    pageLevelFilters: ['trackedRefIds'],
  },
  group: {
    query: groupVulnerabilityResolutionFunnel,
    pageLevelFilters: ['projectId', 'securityAttributesFilters'],
  },
  organization: {
    query: organizationVulnerabilityResolutionFunnel,
    pageLevelFilters: ['projectId'],
  },
};

export default {
  name: 'AgenticAdoptionFunnelPanel',
  components: {
    ExtendedDashboardPanel,
    AgenticAdoptionFunnelChart,
    OverTimePeriodSelector,
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
    return {
      hasFetchError: false,
      selectedTimePeriod: readFromUrl({
        panelId: PANEL_ID,
        paramName: 'timePeriod',
        defaultValue: TIME_PERIOD_DEFAULT,
      }),
      vulnerabilityResolutionFunnel: null,
    };
  },
  apollo: {
    vulnerabilityResolutionFunnel: {
      query() {
        return this.config.query;
      },
      variables() {
        const baseVariables = {
          fullPath: this.fullPath,
          startDate: formatDate(getDateInPast(new Date(), this.selectedTimePeriod), 'isoDate'),
          endDate: formatDate(new Date(), 'isoDate'),
        };

        this.config.pageLevelFilters
          .filter((filterKey) => this.filters[filterKey] !== undefined)
          .forEach((filterKey) => {
            baseVariables[filterKey] = this.filters[filterKey];
          });

        return baseVariables;
      },
      update(data) {
        return data?.namespace?.securityMetrics?.vulnerabilityResolutionFunnel || null;
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
    hasFunnelData() {
      return Boolean(this.vulnerabilityResolutionFunnel);
    },
  },
  watch: {
    selectedTimePeriod(value) {
      writeToUrl({
        panelId: PANEL_ID,
        paramName: 'timePeriod',
        value,
        defaultValue: TIME_PERIOD_DEFAULT,
      });
    },
  },
};
</script>

<template>
  <extended-dashboard-panel
    :title="s__('SecurityReports|SAST triage and remediation funnel')"
    :loading="$apollo.queries.vulnerabilityResolutionFunnel.loading"
    :show-alert-state="hasFetchError"
  >
    <template #filters>
      <over-time-period-selector v-model="selectedTimePeriod" />
    </template>
    <template #body>
      <agentic-adoption-funnel-chart
        v-if="!hasFetchError && hasFunnelData"
        :namespace="namespace"
        :detected-vulnerabilities="vulnerabilityResolutionFunnel.detectedVulnerabilities"
        :true-positives="vulnerabilityResolutionFunnel.truePositives"
        :created-merge-requests="vulnerabilityResolutionFunnel.createdMergeRequests"
        :merged-merge-requests="vulnerabilityResolutionFunnel.mergedMergeRequests"
      />
      <p
        v-else
        class="gl-m-0 gl-flex gl-h-full gl-w-full gl-items-center gl-justify-center gl-p-0 gl-text-center"
        data-testid="agentic-adoption-funnel-empty-state"
      >
        <template v-if="hasFetchError">{{
          __('Something went wrong. Please try again.')
        }}</template>
        <template v-else>{{ __('No results found') }}</template>
      </p>
    </template>
  </extended-dashboard-panel>
</template>
