<script>
import ExtendedDashboardPanel from '~/vue_shared/components/customizable_dashboard/extended_dashboard_panel.vue';
import { s__ } from '~/locale';
import { readFromUrl, writeToUrl } from 'ee/security_dashboard/utils/panel_state_url_sync';
import groupVulnerabilityByAge from 'ee/security_dashboard/graphql/queries/group_vulnerabilities_by_age.query.graphql';
import projectVulnerabilityByAge from 'ee/security_dashboard/graphql/queries/project_vulnerabilities_by_age.query.graphql';
import organizationVulnerabilityByAge from 'ee/security_dashboard/graphql/queries/organization_vulnerabilities_by_age.query.graphql';
import { formatVulnerabilitiesBySeries } from 'ee/security_dashboard/utils/chart_utils';
import PanelSeverityFilter from './panel_severity_filter.vue';
import PanelGroupBy from './panel_group_by.vue';
import VulnerabilitiesByAgeChart from './charts/vulnerabilities_by_age_chart.vue';

const PANEL_ID = 'vulnerabilitiesByAge';
const GROUP_BY_DEFAULT = 'severity';

const NAMESPACE_CONFIG = {
  project: {
    query: projectVulnerabilityByAge,
    pageLevelFilters: ['reportType', 'trackedRefIds'],
  },
  group: {
    query: groupVulnerabilityByAge,
    pageLevelFilters: ['reportType', 'projectId', 'securityAttributesFilters'],
  },
  organization: {
    query: organizationVulnerabilityByAge,
    pageLevelFilters: ['reportType', 'projectId'],
  },
};

export default {
  name: 'VulnerabilitiesByAgePanel',
  components: {
    ExtendedDashboardPanel,
    PanelSeverityFilter,
    PanelGroupBy,
    VulnerabilitiesByAgeChart,
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
      vulnerabilitiesByAge: [],
      severity: readFromUrl({
        panelId: PANEL_ID,
        paramName: 'severity',
        defaultValue: [],
      }),
      groupedBy: readFromUrl({
        panelId: PANEL_ID,
        paramName: 'groupBy',
        defaultValue: GROUP_BY_DEFAULT,
      }),
    };
  },
  apollo: {
    vulnerabilitiesByAge: {
      query() {
        return this.config.query;
      },
      variables() {
        const baseVariables = {
          fullPath: this.fullPath,
          severity: this.severity,
          includeBySeverity: this.groupedBy === 'severity',
          includeByReportType: this.groupedBy === 'reportType',
        };

        this.config.pageLevelFilters
          .filter((filterKey) => this.filters[filterKey] !== undefined)
          .forEach((filterKey) => {
            baseVariables[filterKey] = this.filters[filterKey];
          });

        return baseVariables;
      },
      update(data) {
        return data?.namespace?.securityMetrics?.vulnerabilitiesByAge || [];
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
    hasChartData() {
      return this.bars.length > 0;
    },
    bars() {
      return formatVulnerabilitiesBySeries(this.vulnerabilitiesByAge, {
        groupBy: this.groupedBy,
        isStacked: true,
      });
    },
    labels() {
      return this.vulnerabilitiesByAge.map((bucket) => bucket.name);
    },
  },
  watch: {
    severity(value) {
      writeToUrl({
        panelId: PANEL_ID,
        paramName: 'severity',
        value,
        defaultValue: [],
      });
    },
    groupedBy(value) {
      writeToUrl({
        panelId: PANEL_ID,
        paramName: 'groupBy',
        value,
        defaultValue: GROUP_BY_DEFAULT,
      });
    },
  },
  tooltip: {
    description: s__(
      'SecurityReports|Open vulnerabilities by the amount of time since they were opened.',
    ),
  },
};
</script>

<template>
  <extended-dashboard-panel
    :title="s__('SecurityReports|Vulnerabilities by age')"
    :loading="$apollo.queries.vulnerabilitiesByAge.loading"
    :show-alert-state="hasFetchError"
    :tooltip="$options.tooltip"
  >
    <template #filters>
      <panel-severity-filter v-model="severity" class="gl-mr-2" />
      <panel-group-by v-model="groupedBy" />
    </template>
    <template #body>
      <vulnerabilities-by-age-chart
        v-if="!hasFetchError && hasChartData"
        :bars="bars"
        :labels="labels"
        class="gl-isolate"
      />
      <p
        v-else
        class="gl-m-0 gl-flex gl-h-full gl-w-full gl-items-center gl-justify-center gl-p-0 gl-text-center"
        data-testid="vulnerabilities-by-age-empty-state"
      >
        <template v-if="hasFetchError">{{
          __('Something went wrong. Please try again.')
        }}</template>
        <template v-else>{{ __('No results found') }}</template>
      </p>
    </template>
  </extended-dashboard-panel>
</template>
