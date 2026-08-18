<script>
import { uniq } from 'lodash-es';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import { toYmd, extractQueryResponseFromNamespace } from '~/analytics/shared/utils';
import { CONTRIBUTOR_METRICS } from '~/analytics/shared/constants';
import { BUCKETING_INTERVAL_ALL } from '~/analytics/shared/graphql/constants';
import FlowMetricsQuery from '~/analytics/shared/graphql/flow_metrics.query.graphql';
import DoraMetricsQuery from '~/analytics/shared/graphql/dora_metrics.query.graphql';
import glAbilitiesMixin from '~/vue_shared/mixins/gl_abilities_mixin';
import VulnerabilitiesQuery from '~/analytics/dashboards/graphql/vulnerabilities.query.graphql';
import MergeRequestsQuery from '~/analytics/dashboards/graphql/merge_requests.query.graphql';
import ContributorCountQuery from '~/analytics/dashboards/graphql/contributor_count.query.graphql';
import { MERGE_REQUESTS_STATE_MERGED } from '~/analytics/dashboards/graphql/constants';
import {
  DASHBOARD_LOADING_FAILURE,
  CHART_LOADING_FAILURE,
  SUPPORTED_DORA_METRICS,
  SUPPORTED_FLOW_METRICS,
  SUPPORTED_MERGE_REQUEST_METRICS,
  SUPPORTED_VULNERABILITY_METRICS,
  SUPPORTED_CONTRIBUTOR_METRICS,
  RESTRICTED_METRIC_ERROR,
} from '../constants';
import {
  fetchMetricsForTimePeriods,
  extractGraphqlVulnerabilitiesData,
  extractGraphqlDoraData,
  extractGraphqlFlowData,
  extractGraphqlMergeRequestsData,
  extractGraphqlContributorCountData,
} from '../api';
import {
  generateSkeletonTableData,
  generateMetricComparisons,
  generateSparklineCharts,
  mergeTableData,
  generateDateRanges,
  generateChartTimePeriods,
  generateValueStreamDashboardStartDate,
  getRestrictedTableMetrics,
  generateTableAlerts,
} from '../utils';
import ComparisonTable from './comparison_table.vue';

const now = generateValueStreamDashboardStartDate();
const DASHBOARD_TIME_PERIODS = generateDateRanges(now);
const CHART_TIME_PERIODS = generateChartTimePeriods(now);

export default {
  name: 'ComparisonChart',
  components: {
    ComparisonTable,
  },
  mixins: [glAbilitiesMixin()],
  inject: {
    dataSourceClickhouse: {
      default: false,
    },
  },
  props: {
    requestPath: {
      type: String,
      required: true,
    },
    isProject: {
      type: Boolean,
      required: true,
    },
    excludeMetrics: {
      type: Array,
      required: false,
      default: () => [],
    },
    filterLabels: {
      type: Array,
      required: false,
      default: () => [],
    },
  },
  emits: ['set-alerts'],
  data() {
    return {
      tableData: [],
    };
  },
  computed: {
    filteredQueries() {
      return [
        { metrics: SUPPORTED_DORA_METRICS, queryFn: this.fetchDoraMetricsQuery },
        { metrics: SUPPORTED_FLOW_METRICS, queryFn: this.fetchFlowMetricsQuery },
        { metrics: SUPPORTED_MERGE_REQUEST_METRICS, queryFn: this.fetchMergeRequestsMetricsQuery },
        {
          metrics: SUPPORTED_VULNERABILITY_METRICS,
          queryFn: this.fetchVulnerabilitiesMetricsQuery,
        },
        {
          metrics: SUPPORTED_CONTRIBUTOR_METRICS,
          queryFn: this.fetchContributorsCountQuery,
        },
      ].filter(({ metrics }) => this.areAnyMetricsIncluded(metrics));
    },
    restrictedMetrics() {
      return getRestrictedTableMetrics(this.excludeMetrics, this.glAbilities);
    },
    skippedMetrics() {
      return uniq([
        ...(!this.dataSourceClickhouse ? [CONTRIBUTOR_METRICS.COUNT] : []),
        ...this.restrictedMetrics,
        ...this.excludeMetrics,
      ]);
    },
  },
  async mounted() {
    const failedTableMetrics = await this.resolveQueries(this.fetchTableMetrics);
    const failedChartMetrics = await this.resolveQueries(this.fetchSparklineCharts);

    const alerts = generateTableAlerts([[RESTRICTED_METRIC_ERROR, this.restrictedMetrics]]);
    const warnings = generateTableAlerts([
      [DASHBOARD_LOADING_FAILURE, failedTableMetrics],
      [CHART_LOADING_FAILURE, failedChartMetrics],
    ]);

    if (alerts.length > 0 || warnings.length > 0) {
      this.$emit('set-alerts', { alerts, warnings, canRetry: warnings.length > 0 });
    }
  },
  created() {
    this.tableData = generateSkeletonTableData(this.skippedMetrics);
  },
  methods: {
    areAnyMetricsIncluded(identifiers) {
      return !identifiers.every((identifier) => this.skippedMetrics.includes(identifier));
    },

    async resolveQueries(handler) {
      const result = await Promise.allSettled(this.filteredQueries.map((query) => handler(query)));

      // Return an array of the failed metric IDs
      return result.reduce((acc, { reason = [] }) => acc.concat(reason), []);
    },

    async fetchTableMetrics({ metrics, queryFn }) {
      try {
        const data = await fetchMetricsForTimePeriods(DASHBOARD_TIME_PERIODS, queryFn);
        this.tableData = mergeTableData(this.tableData, generateMetricComparisons(data));
      } catch (error) {
        Sentry.captureException(error);
        throw metrics;
      }
    },

    async fetchSparklineCharts({ metrics, queryFn }) {
      try {
        const data = await fetchMetricsForTimePeriods(CHART_TIME_PERIODS, queryFn);
        this.tableData = mergeTableData(this.tableData, generateSparklineCharts(data));
      } catch (error) {
        Sentry.captureException(error);
        throw metrics;
      }
    },

    async fetchDoraMetricsQuery({ startDate, endDate }, timePeriod) {
      const result = await this.$apollo.query({
        query: DoraMetricsQuery,
        variables: {
          fullPath: this.requestPath,
          interval: BUCKETING_INTERVAL_ALL,
          startDate: toYmd(startDate),
          endDate: toYmd(endDate),
        },
      });

      const responseData = extractQueryResponseFromNamespace({
        result,
        resultKey: 'dora',
      });
      return {
        ...timePeriod,
        ...extractGraphqlDoraData(responseData?.metrics || {}),
      };
    },

    async fetchFlowMetricsQuery({ startDate, endDate }, timePeriod) {
      const result = await this.$apollo.query({
        query: FlowMetricsQuery,
        variables: {
          fullPath: this.requestPath,
          labelNames: this.filterLabels,
          startDate: toYmd(startDate),
          endDate: toYmd(endDate),
        },
      });

      const metrics = extractQueryResponseFromNamespace({ result, resultKey: 'flowMetrics' });
      return {
        ...timePeriod,
        ...extractGraphqlFlowData(metrics || {}),
      };
    },

    async fetchMergeRequestsMetricsQuery({ startDate, endDate }, timePeriod) {
      const result = await this.$apollo.query({
        query: MergeRequestsQuery,
        variables: {
          fullPath: this.requestPath,
          startDate: toYmd(startDate),
          endDate: toYmd(endDate),
          state: MERGE_REQUESTS_STATE_MERGED,
          labelNames: this.filterLabels.length > 0 ? this.filterLabels : null,
        },
      });

      const metrics = extractQueryResponseFromNamespace({
        result,
        resultKey: 'mergeRequests',
      });
      return {
        ...timePeriod,
        ...extractGraphqlMergeRequestsData(metrics || {}),
      };
    },

    async fetchVulnerabilitiesMetricsQuery({ endDate }, timePeriod) {
      const result = await this.$apollo.query({
        query: VulnerabilitiesQuery,
        variables: {
          fullPath: this.requestPath,

          // The vulnerabilities API request takes a date, so the timezone skews it outside the monthly range
          // The vulnerabilites count returns cumulative data for each day
          // we only want to use the value of the last day in the time period
          // so we override the startDate and set it to the same value as the end date
          startDate: toYmd(endDate),
          endDate: toYmd(endDate),
        },
      });

      const responseData = extractQueryResponseFromNamespace({
        result,
        resultKey: 'vulnerabilitiesCountByDay',
      });
      return {
        ...timePeriod,
        ...extractGraphqlVulnerabilitiesData(responseData?.nodes || []),
      };
    },
    async fetchContributorsCountQuery({ startDate, endDate }, timePeriod) {
      const result = await this.$apollo.query({
        query: ContributorCountQuery,
        variables: {
          fullPath: this.requestPath,
          startDate: toYmd(startDate),
          endDate: toYmd(endDate),
        },
      });

      const responseData = extractQueryResponseFromNamespace({
        result,
        resultKey: 'contributors',
      });

      return {
        ...timePeriod,
        ...extractGraphqlContributorCountData(responseData || {}),
      };
    },
  },
  now,
};
</script>
<template>
  <div data-testid="dora-comparison-chart">
    <comparison-table
      :table-data="tableData"
      :request-path="requestPath"
      :is-project="isProject"
      :now="$options.now"
      :filter-labels="filterLabels"
    />
  </div>
</template>
