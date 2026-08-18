<script>
import { GlBarChart, GlChartSeriesLabel } from '@gitlab/ui/src/charts';
import { isEmpty, omit } from 'lodash-es';
import { formatChartTooltipTitle, humanizeChartTooltipValue } from './utils';

export default {
  name: 'BarChart',
  components: {
    GlBarChart,
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
    fullOptions() {
      // Exclude `tooltip` to prevent ECharts from rendering default tooltip
      return omit(this.options, 'tooltip');
    },
    chartData() {
      return omit(this.data, 'contextualData');
    },
    contextualData() {
      return this.data.contextualData ?? {};
    },
  },
  methods: {
    formatTooltipTitle(title, params) {
      const { chartTooltip: { titleFormatter: formatter } = {} } = this.options;
      const yAxisValue = params?.seriesData?.at(0)?.value?.at(1);

      return formatChartTooltipTitle({ title, value: yAxisValue, formatter });
    },
    getPrimaryTooltipData(seriesData) {
      const { chartTooltip: { valueUnit } = {} } = this.options;

      return seriesData.map(({ seriesId, seriesName, color, value: [value] }) => ({
        seriesId,
        seriesName,
        color,
        value: humanizeChartTooltipValue({ unit: valueUnit, value }),
        textClasses: 'gl-font-bold',
      }));
    },
    getContextualTooltipData(seriesData) {
      const { chartTooltip: { contextualData: contextualDataConfig } = {} } = this.options;
      const { contextualData } = this;

      if (isEmpty(contextualDataConfig) || isEmpty(contextualData)) return [];

      const yAxisValue = seriesData[0].value[1];
      const data = contextualData[yAxisValue];

      if (!data) return [];

      return contextualDataConfig.reduce((acc, { key, label, unit }) => {
        if (key in data) {
          const value = humanizeChartTooltipValue({ unit, value: data[key] });
          acc.push({
            seriesId: key,
            seriesName: label,
            color: 'transparent',
            value,
            textClasses: 'gl-font-normal',
          });
        }

        return acc;
      }, []);
    },
    tooltipContent(params) {
      if (!params?.seriesData?.length) return [];

      const { seriesData } = params;

      return [
        ...this.getPrimaryTooltipData(seriesData),
        ...this.getContextualTooltipData(seriesData),
      ];
    },
  },
};
</script>

<template>
  <gl-bar-chart
    :data="chartData"
    :option="fullOptions"
    :x-axis-title="options.xAxis.name"
    :y-axis-title="options.yAxis.name"
    :x-axis-type="options.xAxis.type"
    :presentation="options.presentation"
    height="auto"
    responsive
    tabindex="0"
  >
    <template #tooltip-title="{ title, params }"
      ><span data-testid="chart-tooltip-title">{{
        formatTooltipTitle(title, params)
      }}</span></template
    >
    <template #tooltip-content="{ params }">
      <div
        v-for="{ seriesId, seriesName, color, value, textClasses } in tooltipContent(params)"
        :key="seriesId"
        data-testid="chart-tooltip-item"
        class="gl-flex gl-min-w-28 gl-justify-between gl-leading-20"
      >
        <gl-chart-series-label class="gl-mr-7 gl-text-sm" :color="color">{{
          seriesName
        }}</gl-chart-series-label>
        <span :class="textClasses" data-testid="chart-tooltip-value">{{ value }}</span>
      </div>
    </template>
  </gl-bar-chart>
</template>
