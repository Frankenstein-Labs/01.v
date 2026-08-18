<script>
import { GlStackedColumnChart, GlChartSeriesLabel } from '@gitlab/ui/src/charts';
import { stackedPresentationOptions } from '@gitlab/ui/src/utils/constants';
import { omit, merge } from 'lodash-es';
import {
  formatChartTooltipTitle,
  humanizeChartTooltipValue,
} from 'ee/analytics/analytics_dashboards/components/visualizations/utils';

export default {
  name: 'StackedColumnChart',
  components: {
    GlStackedColumnChart,
    GlChartSeriesLabel,
  },
  props: {
    data: {
      type: Object,
      required: false,
      default: () => ({}),
    },
    options: {
      type: Object,
      required: false,
      default: () => ({}),
    },
  },
  computed: {
    bars() {
      return this.data.bars ?? [];
    },
    groupBy() {
      return this.data.groupBy ?? [];
    },
    fullOptions() {
      const defaultOptions = { xAxis: { axisPointer: { type: 'shadow' } } };

      // Exclude `tooltip` to prevent ECharts from rendering default tooltip
      return merge({}, defaultOptions, omit(this.options, 'tooltip'));
    },
    includeLegendAvgMax() {
      return Boolean(this.options.includeLegendAvgMax);
    },
  },
  methods: {
    formatTooltipTitle(params) {
      const { xAxis: { name: xAxisName } = {}, chartTooltip: { titleFormatter: formatter } = {} } =
        this.options;

      const xAxisValue = params?.value;
      // TODO: To be replaced with `title` slot prop once https://gitlab.com/gitlab-org/gitlab-services/design.gitlab.com/-/work_items/3190 is completed
      const defaultTitle = xAxisName ? `${xAxisValue} (${xAxisName})` : xAxisValue;

      return formatChartTooltipTitle({ title: defaultTitle, value: xAxisValue, formatter });
    },
    getTooltipContent(params) {
      if (!params) return [];

      const { chartTooltip: { valueUnit: unit } = {}, presentation } = this.fullOptions;
      const isTiledPresentation = presentation === stackedPresentationOptions.tiled;

      const tooltipContentEntries = params.seriesData
        .toSorted((a, b) =>
          isTiledPresentation ? a.seriesIndex - b.seriesIndex : b.seriesIndex - a.seriesIndex,
        )
        .map(({ seriesName = '', seriesId, value, borderColor }) => [
          seriesName,
          { seriesId, value: humanizeChartTooltipValue({ unit, value }), color: borderColor },
        ]);

      return Object.fromEntries(tooltipContentEntries);
    },
  },
};
</script>

<template>
  <gl-stacked-column-chart
    :bars="bars"
    :group-by="groupBy"
    :option="fullOptions"
    :x-axis-title="fullOptions.xAxis.name"
    :x-axis-type="fullOptions.xAxis.type"
    :y-axis-title="fullOptions.yAxis.name"
    :presentation="fullOptions.presentation"
    :include-legend-avg-max="includeLegendAvgMax"
    height="auto"
    responsive
    tabindex="0"
  >
    <template #tooltip-title="{ params }">
      <span data-testid="chart-tooltip-title">{{ formatTooltipTitle(params) }}</span>
    </template>
    <template #tooltip-content="{ params }">
      <div
        v-for="({ color, value, seriesId }, seriesName) in getTooltipContent(params)"
        :key="seriesId"
        data-testid="chart-tooltip-item"
        class="gl-flex gl-min-w-28 gl-justify-between gl-leading-20"
      >
        <gl-chart-series-label class="gl-mr-7 gl-text-sm" :color="color">{{
          seriesName
        }}</gl-chart-series-label>
        <span class="gl-font-bold" data-testid="chart-tooltip-value">{{ value }}</span>
      </div>
    </template>
  </gl-stacked-column-chart>
</template>
