<script>
import { GlSkeletonLoader, GlTableLite, GlIcon, GlTooltipDirective } from '@gitlab/ui';
import { formatDate } from '~/lib/utils/datetime_utility';
import { formatNumber } from '~/locale';
import { VSD_COMPARISON_TABLE_TRACKING_PROPERTY } from 'ee/analytics/analytics_dashboards/constants';
import TrendLine from '~/analytics/analytics_dashboards/components/visualizations/data_table/trend_line.vue';
import MetricLabel from '~/analytics/analytics_dashboards/components/visualizations/data_table/metric_label.vue';
import TrendIndicator from '~/analytics/dashboards/components/trend_indicator.vue';
import { buildMetricLink, generateDashboardTableFields } from '../utils';

export default {
  name: 'ComparisonTable',
  components: {
    GlSkeletonLoader,
    GlTableLite,
    MetricLabel,
    TrendIndicator,
    TrendLine,
    GlIcon,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
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
    tableData: {
      type: Array,
      required: true,
    },
    now: {
      type: Date,
      required: true,
    },
    filterLabels: {
      type: Array,
      required: false,
      default: () => [],
    },
  },
  computed: {
    dashboardTableFields() {
      return generateDashboardTableFields(this.now);
    },
    metricLinks() {
      return Object.fromEntries(
        this.tableData.map(({ metric: { identifier } }) => [
          identifier,
          buildMetricLink({
            identifier,
            isProject: this.isProject,
            namespace: this.requestPath,
            filterLabels: this.filterLabels,
          }),
        ]),
      );
    },
  },
  methods: {
    formatDate(date) {
      return formatDate(date, 'mmm d');
    },
    rowAttributes({ metric: { identifier } }) {
      return {
        'data-testid': `dora-chart-metric-${identifier.replaceAll('_', '-')}`,
      };
    },
    getMetricLink(identifier) {
      return this.metricLinks[identifier] ?? '';
    },
    formatNumber,
  },
  VSD_COMPARISON_TABLE_TRACKING_PROPERTY,
};
</script>
<template>
  <gl-table-lite
    :fields="dashboardTableFields"
    :items="tableData"
    table-class="gl-my-0 gl-table-fixed"
    :tbody-tr-attr="rowAttributes"
  >
    <template #head()="{ field: { label, start, end } }">
      <template v-if="!start || !end">
        {{ label }}
      </template>
      <template v-else>
        <div class="gl-mb-2">{{ label }}</div>
        <div class="gl-font-normal">{{ formatDate(start) }} - {{ formatDate(end) }}</div>
      </template>
    </template>

    <template #cell()="{ value: { value, change, valueLimitMessage }, item: { trendStyle } }">
      <span v-if="value === undefined" data-testid="metric-comparison-skeleton">
        <gl-skeleton-loader :lines="1" :width="100" />
      </span>
      <template v-else>
        {{ formatNumber(value) }}
        <gl-icon
          v-if="valueLimitMessage"
          v-gl-tooltip.hover
          class="gl-text-blue-600"
          name="information-o"
          :title="valueLimitMessage"
          data-testid="metric-max-value-info-icon"
        />
        <trend-indicator
          v-else-if="change"
          :change="change"
          :trend-style="trendStyle"
          data-testid="metric-trend-indicator"
          class="gl-ml-3"
        />
      </template>
    </template>

    <template #cell(metric)="{ value: { identifier } }">
      <metric-label
        :data-testid="`${identifier}-metric-cell`"
        :identifier="identifier"
        :link="getMetricLink(identifier)"
        :tracking-property="$options.VSD_COMPARISON_TABLE_TRACKING_PROPERTY"
      />
    </template>

    <template #cell(chart)="{ value: { data, tooltipLabel }, item: { trendStyle } }">
      <trend-line
        v-if="data"
        :data="data"
        :tooltip-label="tooltipLabel"
        :trend-style="trendStyle"
      />
      <div v-else class="gl-py-4" data-testid="metric-chart-skeleton">
        <gl-skeleton-loader :lines="1" :width="100" />
      </div>
    </template>
  </gl-table-lite>
</template>
