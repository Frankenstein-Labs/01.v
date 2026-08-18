<script>
import ExtendedDashboardPanel from '~/vue_shared/components/customizable_dashboard/extended_dashboard_panel.vue';
import { s__ } from '~/locale';
import { formatDate, getDateInPast } from '~/lib/utils/datetime_utility';
import { readFromUrl, writeToUrl } from 'ee/security_dashboard/utils/panel_state_url_sync';
import VulnerabilitiesOverTimeChart from 'ee/security_dashboard/components/shared/charts/open_vulnerabilities_over_time.vue';
import projectVulnerabilitiesOverTime from 'ee/security_dashboard/graphql/queries/project_vulnerabilities_over_time.query.graphql';
import groupVulnerabilitiesOverTime from 'ee/security_dashboard/graphql/queries/group_vulnerabilities_over_time.query.graphql';
import organizationVulnerabilitiesOverTime from 'ee/security_dashboard/graphql/queries/organization_vulnerabilities_over_time.query.graphql';
import { formatVulnerabilitiesBySeries } from 'ee/security_dashboard/utils/chart_utils';
import PanelSeverityFilter from './panel_severity_filter.vue';
import PanelGroupBy from './panel_group_by.vue';
import OverTimePeriodSelector from './over_time_period_selector.vue';

const TIME_PERIODS = {
  THIRTY_DAYS: { key: 'thirtyDays', startDays: 30, endDays: 0 },
  SIXTY_DAYS: { key: 'sixtyDays', startDays: 60, endDays: 31 },
  NINETY_DAYS: { key: 'ninetyDays', startDays: 90, endDays: 61 },
};

const PANEL_ID = 'vulnerabilitiesOverTime';
const GROUP_BY_DEFAULT = 'severity';
const TIME_PERIOD_DEFAULT = 30;

const NAMESPACE_CONFIG = {
  project: {
    query: projectVulnerabilitiesOverTime,
    pageLevelFilters: ['reportType', 'trackedRefIds'],
  },
  group: {
    query: groupVulnerabilitiesOverTime,
    pageLevelFilters: ['reportType', 'projectId', 'securityAttributesFilters'],
  },
  organization: {
    query: organizationVulnerabilitiesOverTime,
    pageLevelFilters: ['reportType', 'projectId'],
  },
};

export default {
  name: 'VulnerabilitiesOverTimePanel',
  components: {
    ExtendedDashboardPanel,
    VulnerabilitiesOverTimeChart,
    PanelGroupBy,
    PanelSeverityFilter,
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
      fetchError: false,
      groupedBy: readFromUrl({
        panelId: PANEL_ID,
        paramName: 'groupBy',
        defaultValue: GROUP_BY_DEFAULT,
      }),
      selectedTimePeriod: readFromUrl({
        panelId: PANEL_ID,
        paramName: 'timePeriod',
        defaultValue: TIME_PERIOD_DEFAULT,
      }),
      severity: readFromUrl({
        panelId: PANEL_ID,
        paramName: 'severity',
        defaultValue: [],
      }),
      isLoading: false,
      chartData: {
        thirtyDays: [],
        sixtyDays: [],
        ninetyDays: [],
      },
    };
  },
  computed: {
    config() {
      return NAMESPACE_CONFIG[this.namespace];
    },
    combinedFilters() {
      return {
        ...this.filters,
        severity: this.severity,
      };
    },
    hasChartData() {
      return this.selectedChartData.length > 0;
    },
    selectedChartData() {
      const selectedChartData = [
        ...(this.selectedTimePeriod >= 90 ? this.chartData.ninetyDays : []),
        ...(this.selectedTimePeriod >= 60 ? this.chartData.sixtyDays : []),
        ...this.chartData.thirtyDays,
      ];

      return formatVulnerabilitiesBySeries(selectedChartData, {
        groupBy: this.groupedBy,
      });
    },
    baseQueryVariables() {
      const baseVariables = {
        severity: this.severity,
        includeBySeverity: this.groupedBy === 'severity',
        includeByReportType: this.groupedBy === 'reportType',
        fullPath: this.fullPath,
      };

      this.config.pageLevelFilters
        .filter((filterKey) => this.filters[filterKey] !== undefined)
        .forEach((filterKey) => {
          baseVariables[filterKey] = this.filters[filterKey];
        });

      return baseVariables;
    },
    selectedTimePeriods() {
      return Object.values(TIME_PERIODS).filter(
        ({ startDays }) => startDays <= this.selectedTimePeriod,
      );
    },
  },
  watch: {
    baseQueryVariables: {
      handler() {
        this.fetchChartData();
      },
      deep: true,
      immediate: true,
    },
    selectedTimePeriod(value) {
      writeToUrl({
        panelId: PANEL_ID,
        paramName: 'timePeriod',
        value,
        defaultValue: TIME_PERIOD_DEFAULT,
      });
      this.fetchChartData();
    },
    groupedBy(value) {
      writeToUrl({
        panelId: PANEL_ID,
        paramName: 'groupBy',
        value,
        defaultValue: GROUP_BY_DEFAULT,
      });
    },
    severity(value) {
      writeToUrl({
        panelId: PANEL_ID,
        paramName: 'severity',
        value,
        defaultValue: [],
      });
    },
  },
  methods: {
    async fetchChartData() {
      this.isLoading = true;
      this.fetchError = false;

      try {
        // Note: we want to load each chunk sequentially for BE-performance reasons
        for await (const timePeriod of this.selectedTimePeriods) {
          await this.fetchTimeRangeData(timePeriod);
        }
      } catch (error) {
        this.fetchError = true;
      } finally {
        this.isLoading = false;
      }
    },
    async fetchTimeRangeData({ key, startDays, endDays }) {
      const startDate = formatDate(getDateInPast(new Date(), startDays), 'isoDate');
      const endDate = formatDate(getDateInPast(new Date(), endDays), 'isoDate');

      const result = await this.$apollo.query({
        query: this.config.query,
        variables: {
          ...this.baseQueryVariables,
          startDate,
          endDate,
        },
      });

      this.chartData[key] =
        result.data.namespace?.securityMetrics?.vulnerabilitiesOverTime?.nodes || [];
    },
  },
  tooltip: {
    description: s__(
      'SecurityReports|Open vulnerability trends over time. To interact with a link in a chart popover, click to pin the popover first.',
    ),
  },
};
</script>

<template>
  <extended-dashboard-panel
    :title="s__('SecurityReports|Vulnerabilities over time')"
    :loading="isLoading"
    :show-alert-state="fetchError"
    :tooltip="$options.tooltip"
  >
    <template #filters>
      <over-time-period-selector v-model="selectedTimePeriod" class="gl-ml-3 gl-mr-2" />
      <panel-severity-filter v-model="severity" class="gl-mr-2" />
      <panel-group-by v-model="groupedBy" />
    </template>
    <template #body>
      <vulnerabilities-over-time-chart
        v-if="!fetchError && hasChartData"
        class="gl-isolate gl-h-full gl-overflow-hidden gl-p-2"
        :chart-series="selectedChartData"
        :grouped-by="groupedBy"
        :filters="combinedFilters"
      />
      <p
        v-else
        class="gl-m-0 gl-flex gl-h-full gl-w-full gl-items-center gl-justify-center gl-p-0 gl-text-center"
        data-testid="vulnerabilities-over-time-empty-state"
      >
        <template v-if="fetchError">{{ __('Something went wrong. Please try again.') }}</template>
        <template v-else>{{ __('No results found') }}</template>
      </p>
    </template>
  </extended-dashboard-panel>
</template>
