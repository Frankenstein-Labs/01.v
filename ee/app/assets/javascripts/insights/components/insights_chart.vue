<script>
import {
  GlColumnChart,
  GlLineChart,
  GlStackedColumnChart,
  GlChartSeriesLabel,
} from '@gitlab/ui/src/charts';

import { isNumber } from 'lodash-es';
import ChartSkeletonLoader from '~/vue_shared/components/resizable_chart/skeleton_loader.vue';
import ChartTooltipText from 'ee/analytics/shared/components/chart_tooltip_text.vue';
import { visitUrl, mergeUrlParams, joinPaths } from '~/lib/utils/url_utility';

import {
  CHART_TYPES,
  INSIGHTS_NO_DATA_TOOLTIP,
  INSIGHTS_CHART_ITEM_SETTINGS,
  INSIGHTS_CHARTS_SUPPORT_DRILLDOWN,
} from '../constants';
import InsightsChartError from './insights_chart_error.vue';

const CHART_HEIGHT = 300;

const extractDataSeriesTooltipValue = (seriesData) => {
  const [, dataSeries] = seriesData;
  if (!dataSeries.data) {
    return [];
  }
  const [, dataSeriesValue] = dataSeries.data;
  return isNumber(dataSeriesValue)
    ? [
        {
          title: dataSeries.seriesName,
          value: dataSeriesValue,
        },
      ]
    : [];
};

export default {
  name: 'InsightsChart',
  components: {
    GlColumnChart,
    GlLineChart,
    GlStackedColumnChart,
    InsightsChartError,
    ChartSkeletonLoader,
    ChartTooltipText,
    GlChartSeriesLabel,
  },
  inject: {
    fullPath: {
      default: '',
    },
    isProject: {
      default: false,
    },
  },
  props: {
    loaded: {
      type: Boolean,
      required: false,
      default: false,
    },
    type: {
      type: String,
      required: false,
      default: null,
    },
    title: {
      type: String,
      required: false,
      default: '',
    },
    description: {
      type: String,
      required: false,
      default: '',
    },
    data: {
      type: Object,
      required: false,
      default: null,
    },
    dataSourceType: {
      type: String,
      required: false,
      default: '',
    },
    filterLabels: {
      type: Array,
      required: false,
      default: () => [],
    },
    collectionLabels: {
      type: Array,
      required: false,
      default: () => [],
    },
    groupBy: {
      type: String,
      required: false,
      default: '',
    },
    error: {
      type: String,
      required: false,
      default: '',
    },
  },
  emits: ['chart-item-clicked'],
  data() {
    return {
      tooltipTitle: null,
      tooltipValue: null,
      tooltipContent: [],
      chart: null,
      activeSeriesId: null,
    };
  },
  computed: {
    chartOptions() {
      let options = {
        yAxis: {
          minInterval: 1,
        },
        cursor: 'auto',
      };

      if (this.type === this.$options.chartTypes.LINE) {
        options = {
          ...options,
          xAxis: {
            ...options.xAxis,
            name: this.data.xAxisTitle,
            type: 'category',
          },
          yAxis: {
            ...options.yAxis,
            name: this.data.yAxisTitle,
            type: 'value',
          },
        };
      }

      if (this.supportsDrillDown) {
        options = {
          ...options,
          cursor: 'pointer',
          emphasis: {
            focus: 'series',
          },
        };
      }

      return { dataZoom: [{ type: 'slider' }], ...options };
    },
    isColumnChart() {
      return [this.$options.chartTypes.BAR, this.$options.chartTypes.PIE].includes(this.type);
    },
    isStackedColumnChart() {
      return this.type === this.$options.chartTypes.STACKED_BAR;
    },
    isLineChart() {
      return this.type === this.$options.chartTypes.LINE;
    },
    supportsDrillDown() {
      return INSIGHTS_CHARTS_SUPPORT_DRILLDOWN.includes(this.dataSourceType);
    },
    namespacePath() {
      return this.isProject ? this.fullPath : joinPaths('groups', this.fullPath);
    },
    drillThroughPathSuffix() {
      const { groupPathSuffix, projectPathSuffix } =
        INSIGHTS_CHART_ITEM_SETTINGS[this.dataSourceType];

      return this.isProject ? projectPathSuffix : groupPathSuffix;
    },
    chartItemUrl() {
      return joinPaths(
        '/',
        gon.relative_url_root || '',
        this.namespacePath,
        this.drillThroughPathSuffix,
      );
    },
    hasFilterLabels() {
      return Boolean(this.filterLabels.length);
    },
    hasCollectionLabels() {
      return Boolean(this.collectionLabels.length);
    },
  },
  beforeDestroy() {
    if (this.chart && this.supportsDrillDown) {
      this.chart.off('mouseover', this.onChartDataSeriesMouseOver);
      this.chart.off('mouseout', this.onChartDataSeriesMouseOut);
    }
  },
  methods: {
    onChartCreated(chart) {
      this.chart = chart;

      if (this.supportsDrillDown) {
        this.chart.on('mouseover', 'series', this.onChartDataSeriesMouseOver);
        this.chart.on('mouseout', 'series', this.onChartDataSeriesMouseOut);
      }
    },
    onChartItemClicked({ params }) {
      const { seriesName, name } = params;
      // handles edge case where, when groupBy is undefined and collectionLabels have been added, the latter define the x-axis rather than dates, so we use chart item's `name` instead
      const collectionLabel = this.groupBy ? seriesName : name;
      const canDrillDown = collectionLabel !== 'undefined' && this.supportsDrillDown;

      if (!canDrillDown) return;

      this.$emit('chart-item-clicked');

      const drillDownLabels = [
        ...(this.hasFilterLabels ? this.filterLabels : []),
        ...(this.hasCollectionLabels ? [collectionLabel] : []),
      ];

      const chartItemUrlWithParams = mergeUrlParams(
        { label_name: drillDownLabels },
        this.chartItemUrl,
        { spreadArrays: true },
      );

      visitUrl(drillDownLabels.length ? chartItemUrlWithParams : this.chartItemUrl);
    },
    formatTooltipText(params) {
      const { seriesData } = params;
      const tooltipValue = extractDataSeriesTooltipValue(seriesData);

      this.tooltipTitle = params.value;
      this.tooltipValue = tooltipValue;
    },
    formatBarChartTooltip({ value: title, seriesData }) {
      this.tooltipTitle = title;
      this.tooltipContent = seriesData
        .map(({ borderColor, seriesId, seriesName, seriesIndex, value }) => ({
          color: borderColor,
          seriesId,
          seriesName,
          seriesIndex,
          value: value ?? INSIGHTS_NO_DATA_TOOLTIP,
        }))
        .reverse();
    },
    onChartDataSeriesMouseOver({ seriesId }) {
      this.activeSeriesId = seriesId;
    },
    onChartDataSeriesMouseOut() {
      this.activeSeriesId = null;
    },
    activeChartSeriesLabelStyles(seriesId) {
      if (!this.activeSeriesId) return null;

      const isSeriesActive = this.activeSeriesId === seriesId;

      return {
        'gl-font-bold': isSeriesActive,
        'gl-opacity-4': !isSeriesActive,
      };
    },
  },
  height: CHART_HEIGHT,
  chartTypes: CHART_TYPES,
  i18n: {
    noDataText: INSIGHTS_NO_DATA_TOOLTIP,
  },
};
</script>
<template>
  <div v-if="error" class="insights-chart">
    <insights-chart-error
      :chart-name="title"
      :title="__('This chart could not be displayed')"
      :summary="__('Please check the configuration file for this chart')"
      :error="error"
    />
  </div>
  <div v-else class="insights-chart">
    <h5 class="gl-text-center">{{ title }}</h5>
    <p v-if="description" class="gl-text-center">{{ description }}</p>
    <gl-column-chart
      v-if="loaded && isColumnChart"
      v-bind="$attrs"
      :height="$options.height"
      :bars="data.datasets"
      x-axis-type="category"
      :x-axis-title="data.xAxisTitle"
      :y-axis-title="data.yAxisTitle"
      :option="chartOptions"
      @created="onChartCreated"
      @chartItemClicked="onChartItemClicked"
    />
    <gl-stacked-column-chart
      v-else-if="loaded && isStackedColumnChart"
      v-bind="$attrs"
      :height="$options.height"
      :bars="data.datasets"
      :group-by="data.labels"
      x-axis-type="category"
      :x-axis-title="data.xAxisTitle"
      :y-axis-title="data.yAxisTitle"
      :option="chartOptions"
      :format-tooltip-text="formatBarChartTooltip"
      @created="onChartCreated"
      @chartItemClicked="onChartItemClicked"
    >
      <template #tooltip-title>{{ tooltipTitle }}</template>
      <template #tooltip-content>
        <div
          v-for="{ seriesId, seriesName, color, value } in tooltipContent"
          :key="seriesId"
          class="gl-flex gl-min-w-20 gl-justify-between gl-leading-20"
          :class="activeChartSeriesLabelStyles(seriesId)"
        >
          <gl-chart-series-label class="gl-mr-7 gl-text-sm" :color="color">
            {{ seriesName }}
          </gl-chart-series-label>
          <div class="gl-font-bold">{{ value }}</div>
        </div>
      </template>
    </gl-stacked-column-chart>
    <template v-else-if="loaded && isLineChart">
      <gl-line-chart
        v-bind="$attrs"
        :height="$options.height"
        :data="data.datasets"
        :option="chartOptions"
        :format-tooltip-text="formatTooltipText"
        show-legend
        @created="onChartCreated"
        @chartItemClicked="onChartItemClicked"
      >
        <template #tooltip-title> {{ tooltipTitle }} </template>
        <template #tooltip-content>
          <chart-tooltip-text
            :empty-value-text="$options.i18n.noDataText"
            :tooltip-value="tooltipValue"
          />
        </template>
      </gl-line-chart>
    </template>
    <chart-skeleton-loader v-else />
  </div>
</template>
