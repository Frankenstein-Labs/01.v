<script>
import { uniq } from 'lodash-es';
import {
  GlTableLite,
  GlSkeletonLoader,
  GlTooltip,
  GlTooltipDirective,
  GlSprintf,
  GlLink,
  GlIcon,
} from '@gitlab/ui';
import { toYmd, extractQueryResponseFromNamespace } from '~/analytics/shared/utils';
import { UNITS, CONTRIBUTOR_METRICS } from '~/analytics/shared/constants';
import { BUCKETING_INTERVAL_ALL } from '~/analytics/shared/graphql/constants';
import { dasherize } from '~/lib/utils/text_utility';
import { formatNumber } from '~/locale';
import glAbilitiesMixin from '~/vue_shared/mixins/gl_abilities_mixin';
import DoraMetricsQuery from '~/analytics/shared/graphql/dora_metrics.query.graphql';
import FlowMetricsQuery from '~/analytics/shared/graphql/flow_metrics.query.graphql';
import { AI_IMPACT_TABLE_TRACKING_PROPERTY } from 'ee/analytics/analytics_dashboards/constants';
import MetricLabel from '~/analytics/analytics_dashboards/components/visualizations/data_table/metric_label.vue';
import TrendLine from '~/analytics/analytics_dashboards/components/visualizations/data_table/trend_line.vue';
import TrendIndicator from '~/analytics/dashboards/components/trend_indicator.vue';
import { formatMetric } from '~/analytics/dashboards/utils';
import AggregatedPipelineMetricsQuery from '~/analytics/dashboards/graphql/get_aggregate_pipeline_metrics.query.graphql';
import VulnerabilitiesQuery from '~/analytics/dashboards/graphql/vulnerabilities.query.graphql';
import MergeRequestsQuery from '~/analytics/dashboards/graphql/merge_requests.query.graphql';
import ContributorCountQuery from '~/analytics/dashboards/graphql/contributor_count.query.graphql';
import { MERGE_REQUESTS_STATE_MERGED } from '~/analytics/dashboards/graphql/constants';
import AiMetricsQuery from '~/analytics/dashboards/ai_impact/graphql/ai_metrics.query.graphql';
import {
  SUPPORTED_DORA_METRICS,
  SUPPORTED_VULNERABILITY_METRICS,
  SUPPORTED_CONTRIBUTOR_METRICS,
  SUPPORTED_MERGE_REQUEST_METRICS,
  SUPPORTED_FLOW_METRICS,
  SUPPORTED_PIPELINE_ANALYTICS_METRICS,
  DASHBOARD_LOADING_FAILURE,
  RESTRICTED_METRIC_ERROR,
  TREND_STYLE_NONE,
} from '../../constants';
import {
  mergeTableData,
  generateValueStreamDashboardStartDate,
  getRestrictedTableMetrics,
} from '../../utils';
import {
  generateDateRanges,
  generateTableColumns,
  generateSkeletonTableData,
  generateTableRows,
  generateTableAlerts,
} from '../utils';
import {
  SUPPORTED_AI_METRICS,
  HIDE_METRIC_DRILL_DOWN,
  AI_IMPACT_DATA_NOT_AVAILABLE_TOOLTIPS,
  AI_IMPACT_TABLE_METRICS,
} from '../constants';
import {
  fetchMetricsForTimePeriods,
  extractGraphqlVulnerabilitiesData,
  extractGraphqlDoraData,
  extractGraphqlFlowData,
  extractGraphqlMergeRequestsData,
  extractGraphqlContributorCountData,
  extractAggregatedPipelineMetricsData,
} from '../../api';
import {
  extractGraphqlAiData,
  skippedFlowMetrics,
  skippedDoraMetrics,
  skippedVulnerabilityMetrics,
  skippedPipelineMetrics,
  skippedAiMetrics,
} from '../api';

export default {
  name: 'MetricTable',
  components: {
    GlTableLite,
    GlTooltip,
    GlSprintf,
    GlLink,
    GlSkeletonLoader,
    GlIcon,
    MetricLabel,
    TrendIndicator,
    TrendLine,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  mixins: [glAbilitiesMixin()],
  inject: {
    dataSourceClickhouse: {
      default: false,
    },
  },
  props: {
    namespace: {
      type: String,
      required: true,
    },
    metricLinks: {
      type: Object,
      required: false,
      default: () => ({}),
    },
    includeMetrics: {
      type: Array,
      required: false,
      default: () => [],
    },
    excludeMetrics: {
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
    dashboardStartDate() {
      return generateValueStreamDashboardStartDate();
    },
    dashboardTimePeriods() {
      return generateDateRanges(this.dashboardStartDate);
    },
    dashboardTableFields() {
      return generateTableColumns(this.dashboardStartDate);
    },
    tableQueries() {
      return [
        { metrics: SUPPORTED_DORA_METRICS, queryFn: this.fetchDoraMetricsQuery },
        { metrics: SUPPORTED_FLOW_METRICS, queryFn: this.fetchFlowMetricsQuery },
        { metrics: SUPPORTED_AI_METRICS, queryFn: this.fetchAiMetricsQuery },
        { metrics: SUPPORTED_MERGE_REQUEST_METRICS, queryFn: this.fetchMergeRequestsMetricsQuery },
        {
          metrics: SUPPORTED_VULNERABILITY_METRICS,
          queryFn: this.fetchVulnerabilitiesMetricsQuery,
        },
        {
          metrics: SUPPORTED_CONTRIBUTOR_METRICS,
          queryFn: this.fetchContributorsCountQuery,
        },
        {
          metrics: SUPPORTED_PIPELINE_ANALYTICS_METRICS,
          queryFn: this.fetchAggregatedPipelineMetrics,
        },
      ].filter(({ metrics }) => !this.areAllMetricsSkipped(metrics));
    },
    omittedMetrics() {
      if (this.includeMetrics.length > 0) {
        return Object.keys(AI_IMPACT_TABLE_METRICS).filter(
          (metric) => !this.includeMetrics.includes(metric),
        );
      }

      return this.excludeMetrics;
    },
    restrictedMetrics() {
      return getRestrictedTableMetrics(this.omittedMetrics, this.glAbilities);
    },
    skippedMetrics() {
      return uniq([
        ...(!this.dataSourceClickhouse ? [CONTRIBUTOR_METRICS.COUNT] : []),
        ...this.restrictedMetrics,
        ...this.omittedMetrics,
      ]);
    },
  },
  async mounted() {
    const failedTableMetrics = await this.resolveQueries(this.fetchTableMetrics);

    const alerts = generateTableAlerts([[RESTRICTED_METRIC_ERROR, this.restrictedMetrics]]);
    const warnings = generateTableAlerts([[DASHBOARD_LOADING_FAILURE, failedTableMetrics]]);

    if (alerts.length > 0 || warnings.length > 0) {
      this.$emit('set-alerts', { alerts, warnings, canRetry: warnings.length > 0 });
    }
  },
  created() {
    this.tableData = generateSkeletonTableData(this.skippedMetrics);
  },
  methods: {
    areAllMetricsSkipped(metrics) {
      return metrics.every((metric) => this.skippedMetrics.includes(metric));
    },

    rowAttributes({ metric: { identifier } }) {
      return {
        'data-testid': `ai-impact-metric-${dasherize(identifier)}`,
      };
    },

    metricLink(identifier) {
      if (HIDE_METRIC_DRILL_DOWN.includes(identifier)) return '';
      return this.metricLinks[identifier] || '';
    },

    trackingProperty(identifier) {
      return HIDE_METRIC_DRILL_DOWN.includes(identifier) ? '' : AI_IMPACT_TABLE_TRACKING_PROPERTY;
    },

    isValidTrend(value) {
      return typeof value === 'number' && value !== 0;
    },

    formatInvalidTrend(value) {
      return value === 0 ? formatMetric(0, UNITS.PERCENT) : value;
    },

    async resolveQueries(handler) {
      const result = await Promise.allSettled(this.tableQueries.map((query) => handler(query)));

      // Return an array of the failed metric IDs
      return result.reduce((failedMetrics, { reason = [] }) => failedMetrics.concat(reason), []);
    },

    async fetchTableMetrics({ metrics, queryFn }) {
      try {
        const data = await fetchMetricsForTimePeriods(this.dashboardTimePeriods, queryFn);
        this.tableData = mergeTableData(this.tableData, generateTableRows(data));
      } catch (error) {
        throw metrics;
      }
    },

    async fetchDoraMetricsQuery({ startDate, endDate }, timePeriod) {
      const result = await this.$apollo.query({
        query: DoraMetricsQuery,
        variables: {
          ...skippedDoraMetrics(this.skippedMetrics),
          fullPath: this.namespace,
          interval: BUCKETING_INTERVAL_ALL,
          startDate,
          endDate,
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
          ...skippedFlowMetrics(this.skippedMetrics),
          fullPath: this.namespace,
          startDate,
          endDate,
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
          fullPath: this.namespace,
          startDate: toYmd(startDate),
          endDate: toYmd(endDate),
          state: MERGE_REQUESTS_STATE_MERGED,
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
          ...skippedVulnerabilityMetrics(this.skippedMetrics),
          fullPath: this.namespace,

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
          fullPath: this.namespace,
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

    async fetchAiMetricsQuery({ startDate, endDate }, timePeriod) {
      const result = await this.$apollo.query({
        query: AiMetricsQuery,
        variables: {
          ...skippedAiMetrics(this.skippedMetrics),
          fullPath: this.namespace,
          startDate: toYmd(startDate),
          endDate: toYmd(endDate),
        },
      });

      const responseData = extractQueryResponseFromNamespace({
        result,
        resultKey: 'aiMetrics',
      });
      return {
        ...timePeriod,
        ...extractGraphqlAiData(responseData),
      };
    },

    async fetchAggregatedPipelineMetrics({ startDate, endDate }, timePeriod) {
      const result = await this.$apollo.query({
        query: AggregatedPipelineMetricsQuery,
        variables: {
          ...skippedPipelineMetrics(this.skippedMetrics),
          fullPath: this.namespace,
          fromTime: startDate,
          toTime: endDate,
        },
      });

      const { aggregate: metrics = {} } = extractQueryResponseFromNamespace({
        result,
        resultKey: 'pipelineAnalytics',
      });

      return {
        ...timePeriod,
        ...extractAggregatedPipelineMetricsData(metrics),
      };
    },
    formatNumber,
    dataNotAvailableTooltip(metricId, dateRangeEnd) {
      const tooltip = AI_IMPACT_DATA_NOT_AVAILABLE_TOOLTIPS[metricId];
      return tooltip && dateRangeEnd < tooltip.startDate ? tooltip : undefined;
    },
  },
  dataNotAvailableTooltips: AI_IMPACT_DATA_NOT_AVAILABLE_TOOLTIPS,
  TREND_STYLE_NONE,
};
</script>
<template>
  <gl-table-lite
    :fields="dashboardTableFields"
    :items="tableData"
    :tbody-tr-attr="rowAttributes"
    responsive
    borderless
  >
    <template #head(change)="{ field: { label, tooltip } }">
      <div class="gl-mb-2">
        <span v-if="!tooltip">
          {{ label }}
        </span>
        <span
          v-else
          v-gl-tooltip="tooltip"
          :aria-label="tooltip"
          class="gl-cursor-pointer"
          tabindex="0"
        >
          {{ label }}
        </span>
      </div>
    </template>

    <template #cell(metric)="{ value: { identifier } }">
      <metric-label
        :identifier="identifier"
        :link="metricLink(identifier)"
        :tracking-property="trackingProperty(identifier)"
      />
    </template>

    <template
      #cell()="{
        value: { value, tooltip, valueLimitMessage },
        field: { key, end },
        item: {
          metric: { identifier },
        },
      }"
    >
      <span v-if="value === undefined" data-testid="metric-skeleton-loader">
        <gl-skeleton-loader :lines="1" :width="35" equal-width-lines class="gl-float-right" />
      </span>
      <span v-else data-testid="ai-impact-table-value-cell">
        <span
          :ref="`${key}-${identifier}`"
          :class="{
            'gl-cursor-pointer hover:gl-underline':
              tooltip || dataNotAvailableTooltip(identifier, end),
          }"
          data-testid="formatted-metric-value"
        >
          {{ formatNumber(value) }}
          <gl-icon
            v-if="valueLimitMessage"
            v-gl-tooltip.hover
            class="gl-text-blue-600"
            name="information-o"
            :title="valueLimitMessage"
            data-testid="metric-max-value-info-icon"
          />
        </span>

        <gl-tooltip
          v-if="tooltip || dataNotAvailableTooltip(identifier, end)"
          :target="() => $refs[`${key}-${identifier}`]"
        >
          <gl-sprintf
            v-if="dataNotAvailableTooltip(identifier, end)"
            :message="dataNotAvailableTooltip(identifier, end).message"
          >
            <template #link="{ content }">
              <gl-link :href="dataNotAvailableTooltip(identifier, end).link" target="_blank">{{
                content
              }}</gl-link>
            </template>
          </gl-sprintf>
          <template v-else>{{ tooltip }}</template>
        </gl-tooltip>
      </span>
    </template>

    <template #cell(change)="{ value: { value, tooltip }, item: { trendStyle } }">
      <span v-if="value === undefined" data-testid="metric-skeleton-loader">
        <gl-skeleton-loader :lines="1" :width="50" equal-width-lines class="gl-float-right" />
      </span>
      <trend-indicator v-else-if="isValidTrend(value)" :change="value" :trend-style="trendStyle" />
      <span
        v-else
        v-gl-tooltip="tooltip"
        :aria-label="tooltip"
        class="gl-cursor-pointer gl-text-sm gl-text-subtle hover:gl-underline"
        data-testid="metric-cell-no-change"
        tabindex="0"
      >
        {{ formatInvalidTrend(value) }}
      </span>
    </template>

    <template #cell(chart)="{ value: { data, tooltipLabel } }">
      <trend-line
        v-if="data"
        :data="data"
        :tooltip-label="tooltipLabel"
        :trend-style="$options.TREND_STYLE_NONE"
      />
      <div v-else class="gl-py-4" data-testid="metric-chart-skeleton">
        <gl-skeleton-loader :lines="1" :width="100" />
      </div>
    </template>
  </gl-table-lite>
</template>
