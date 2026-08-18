<script>
import { DATA_VIZ_BLUE_500 } from '@gitlab/ui/src/tokens/build/js/tokens';
import { GlLineChart } from '@gitlab/ui/src/charts';
import { GlIcon, GlTooltipDirective } from '@gitlab/ui';
import ChartTooltipText from 'ee/analytics/shared/components/chart_tooltip_text.vue';
import { buildNullSeries } from 'ee/analytics/shared/utils';
import { isNumeric } from '~/lib/utils/number_utils';
import { humanizeTimeInterval } from '~/lib/utils/datetime_utility';
import { capitalizeFirstCharacter } from '~/lib/utils/text_utility';
import { sprintf, __ } from '~/locale';
import { formatDurationChartDate } from 'ee/analytics/cycle_analytics/utils';
import {
  DURATION_STAGE_TIME_DESCRIPTION,
  DURATION_STAGE_TIME_LABEL,
  DURATION_CHART_X_AXIS_TITLE,
  DURATION_CHART_Y_AXIS_TITLE,
  DURATION_CHART_TOOLTIP_NO_DATA,
} from '../../constants';
import NoDataAvailableState from '../no_data_available_state.vue';

export default {
  name: 'StageChart',
  components: {
    GlIcon,
    GlLineChart,
    ChartTooltipText,
    NoDataAvailableState,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  props: {
    stageTitle: {
      type: String,
      required: true,
    },
    plottableData: {
      type: Array,
      required: true,
    },
  },
  data() {
    return { tooltipTitle: '', tooltipContent: [] };
  },
  computed: {
    hasData() {
      return this.plottableData.some((dataPoint) => dataPoint[1] !== null);
    },
    title() {
      return sprintf(
        DURATION_STAGE_TIME_LABEL,
        {
          title: capitalizeFirstCharacter(this.stageTitle),
        },
        false,
      );
    },
    tooltipText() {
      return DURATION_STAGE_TIME_DESCRIPTION;
    },
    chartData() {
      const valuesSeries = [
        {
          name: this.$options.i18n.yAxisTitle,
          data: this.plottableData,
          lineStyle: {
            color: DATA_VIZ_BLUE_500,
          },
        },
      ];

      const nullSeries = buildNullSeries({
        seriesData: valuesSeries,
        nullSeriesTitle: sprintf(__('%{chartTitle} no data series'), {
          chartTitle: DURATION_CHART_Y_AXIS_TITLE,
        }),
      });
      const [nullData, nonNullData] = nullSeries;
      return [nonNullData, { ...nullData, showSymbol: false }];
    },
    chartOptions() {
      return {
        grid: { containLabel: true },
        xAxis: {
          name: this.$options.i18n.xAxisTitle,
          type: 'time',
          axisLabel: {
            formatter: formatDurationChartDate,
          },
        },
        yAxis: {
          name: this.$options.i18n.yAxisTitle,
          nameGap: 65,
          type: 'value',
          axisLabel: {
            formatter: (value) => humanizeTimeInterval(value, { abbreviated: true }),
          },
        },
        dataZoom: [
          {
            type: 'slider',
            bottom: 10,
            start: 0,
          },
        ],
      };
    },
  },
  methods: {
    renderTooltip({ seriesData }) {
      const [dateTime, metric] = seriesData[0].data;
      this.tooltipTitle = formatDurationChartDate(dateTime);
      this.tooltipContent = isNumeric(metric)
        ? [
            {
              title: this.$options.i18n.yAxisTitle,
              value: humanizeTimeInterval(metric),
            },
          ]
        : [];
    },
  },
  i18n: {
    xAxisTitle: DURATION_CHART_X_AXIS_TITLE,
    yAxisTitle: DURATION_CHART_Y_AXIS_TITLE,
    noData: DURATION_CHART_TOOLTIP_NO_DATA,
  },
};
</script>
<template>
  <div class="gl-flex gl-flex-col" data-testid="vsa-duration-chart">
    <h4 class="gl-mt-0">
      {{ title }}&nbsp;<gl-icon v-gl-tooltip.hover name="information-o" :title="tooltipText" />
    </h4>
    <gl-line-chart
      v-if="hasData"
      :option="chartOptions"
      :data="chartData"
      :format-tooltip-text="renderTooltip"
      :include-legend-avg-max="false"
      :show-legend="false"
    >
      <template #tooltip-title>
        <div>{{ tooltipTitle }}</div>
      </template>
      <template #tooltip-content>
        <chart-tooltip-text
          :empty-value-text="$options.i18n.noData"
          :tooltip-value="tooltipContent"
        />
      </template>
    </gl-line-chart>
    <no-data-available-state v-else />
  </div>
</template>
