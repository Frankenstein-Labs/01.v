<script>
import { GlAreaChart, GlChartSeriesLabel } from '@gitlab/ui/src/charts';
import { GlIcon, GlTooltipDirective } from '@gitlab/ui';
import { humanizeTimeInterval } from '~/lib/utils/datetime_utility';
import { buildNullSeries } from 'ee/analytics/shared/utils';
import { isNumeric } from '~/lib/utils/number_utils';
import { formatDurationChartDate } from 'ee/analytics/cycle_analytics/utils';
import {
  DURATION_CHART_Y_AXIS_TITLE,
  DURATION_TOTAL_TIME_DESCRIPTION,
  DURATION_TOTAL_TIME_LABEL,
  DURATION_OVERVIEW_CHART_NO_DATA,
  DURATION_OVERVIEW_CHART_NO_DATA_LEGEND_ITEM,
} from '../../constants';
import {
  DEFAULT_NULL_SERIES_OPTIONS,
  STACKED_AREA_CHART_SERIES_OPTIONS,
  STACKED_AREA_CHART_NULL_SERIES_OPTIONS,
} from '../../../shared/constants';
import NoDataAvailableState from '../no_data_available_state.vue';

export default {
  name: 'OverviewChart',
  components: {
    GlAreaChart,
    GlChartSeriesLabel,
    GlIcon,
    NoDataAvailableState,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  props: {
    plottableData: {
      type: Array,
      required: true,
    },
  },
  data() {
    return {
      chart: null,
      tooltipTitle: '',
      tooltipContent: [],
      activeDataSeries: '',
    };
  },
  computed: {
    hasData() {
      return this.plottableData.some(({ data }) => data.some(([, metric]) => metric !== null));
    },
    chartData() {
      const nonNullSeries = [];
      const nullSeries = [];

      this.plottableData.forEach(({ name: seriesName, data: seriesData }) => {
        const valuesSeries = {
          name: seriesName,
          data: seriesData,
        };

        const [nullData, nonNullData] = buildNullSeries({
          seriesData: [valuesSeries],
          nullSeriesTitle: seriesName, // to simultaneously toggle both stage and corresponding null series from legend
          nullSeriesOptions: {
            ...DEFAULT_NULL_SERIES_OPTIONS,
            ...STACKED_AREA_CHART_NULL_SERIES_OPTIONS,
          },
        });

        const { data, name } = nonNullData;

        nonNullSeries.push({ data, name, ...STACKED_AREA_CHART_SERIES_OPTIONS });
        nullSeries.push(nullData);
      });

      return [...nonNullSeries, ...nullSeries];
    },
    chartOptions() {
      return {
        grid: { containLabel: true },
        xAxis: {
          name: '',
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
      };
    },
    compiledChartOptions() {
      return this.chart ? this.chart.getOption() : null;
    },
    legendSeriesInfo() {
      if (!this.compiledChartOptions) return [];

      const { series } = this.compiledChartOptions;
      const seriesInfo = series.map(({ name, lineStyle }) => ({
        name,
        ...lineStyle,
      }));

      const nonNullSeriesInfo = this.getNonNullSeriesData(seriesInfo);

      return [...nonNullSeriesInfo, DURATION_OVERVIEW_CHART_NO_DATA_LEGEND_ITEM];
    },
  },
  beforeDestroy() {
    if (this.chart) {
      this.chart.off('mouseover', this.onChartDataSeriesMouseOver);
      this.chart.off('mouseout', this.onChartDataSeriesMouseOut);
    }
  },
  methods: {
    getNonNullSeriesData(seriesData) {
      const seriesDataHalf = Math.ceil(seriesData.length / 2);
      /**
       * Since series data is structured as follows: [...nonNullSeries, ...nullSeries]
       * we want to slice the array and return the first half
       */
      return seriesData.slice(0, seriesDataHalf);
    },
    formatTooltipText({ seriesData }) {
      const [dateTime] = seriesData[0].data;
      this.tooltipTitle = formatDurationChartDate(dateTime);

      const nonNullSeries = this.getNonNullSeriesData(seriesData);

      this.tooltipContent = nonNullSeries.map(({ seriesName, color, seriesId, data }) => {
        const [, metric] = data;

        return {
          seriesId,
          label: seriesName,
          value: isNumeric(metric) ? humanizeTimeInterval(metric) : this.$options.i18n.noData,
          color,
        };
      });
    },
    onChartCreated(chart) {
      this.chart = chart;

      this.chart.on('mouseover', 'series', this.onChartDataSeriesMouseOver);
      this.chart.on('mouseout', 'series', this.onChartDataSeriesMouseOut);
    },
    onChartDataSeriesMouseOver({ seriesId }) {
      this.activeDataSeries = seriesId;
    },
    onChartDataSeriesMouseOut() {
      this.activeDataSeries = null;
    },
  },
  i18n: {
    title: DURATION_TOTAL_TIME_LABEL,
    tooltipText: DURATION_TOTAL_TIME_DESCRIPTION,
    yAxisTitle: DURATION_CHART_Y_AXIS_TITLE,
    noData: DURATION_OVERVIEW_CHART_NO_DATA,
  },
};
</script>

<template>
  <div class="gl-flex gl-flex-col" data-testid="vsa-duration-overview-chart">
    <h4 class="gl-mt-0">
      {{ $options.i18n.title }}&nbsp;<gl-icon
        v-gl-tooltip.hover
        name="information-o"
        :title="$options.i18n.tooltipText"
      />
    </h4>
    <gl-area-chart
      v-if="hasData"
      :option="chartOptions"
      :data="chartData"
      :include-legend-avg-max="false"
      :format-tooltip-text="formatTooltipText"
      :legend-series-info="legendSeriesInfo"
      @created="onChartCreated"
    >
      <template #tooltip-title>
        <div>{{ tooltipTitle }}</div>
      </template>

      <template #tooltip-content>
        <div
          v-for="metric in tooltipContent"
          :key="metric.seriesId"
          class="gl-flex gl-min-w-20 gl-justify-between gl-leading-24"
          :class="{ 'gl-font-bold': activeDataSeries === metric.seriesId }"
        >
          <gl-chart-series-label class="gl-mr-7" :color="metric.color">
            {{ metric.label }}
          </gl-chart-series-label>
          <div>{{ metric.value }}</div>
        </div>
      </template>
    </gl-area-chart>
    <no-data-available-state v-else />
  </div>
</template>
