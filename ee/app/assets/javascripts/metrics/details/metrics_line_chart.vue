<script>
import { GlLineChart, GlChartSeriesLabel } from '@gitlab/ui/src/charts';
import { s__ } from '~/locale';
import { formatDate, convertNanoToMs } from '~/lib/utils/datetime_utility';
import { SHORT_DATE_TIME_FORMAT } from '~/observability/constants';

const SYMBOL_SIZE_DEFAULT = 6;
const SYMBOL_SIZE_HIGHLIGHTED = 12;

/**
 * The SVG has been taken from https://gitlab.com/gitlab-org/gitlab-svgs/blob/main/sprite_icons/status_created.svg?plain=1
 * and converted to a path.
 */
const BULLSYEYE_ICON_SVG_PATH =
  'path://M11.25 8c0 1.79-1.46 3.25-3.25 3.25S4.75 9.79 4.75 8 6.21 4.75 8 4.75 11.25 6.21 11.25 8ZM14 8c0-3.31-2.69-6-6-6S2 4.69 2 8s2.69 6 6 6 6-2.69 6-6ZM1 8c0-3.87 3.13-7 7-7s7 3.13 7 7-3.13 7-7 7-7-3.13-7-7Z';

export default {
  name: 'MetricsLineChart',
  components: {
    GlLineChart,
    GlChartSeriesLabel,
  },
  i18n: {
    xAxisTitle: s__('ObservabilityMetrics|Date'),
    yAxisTitle: s__('ObservabilityMetrics|Value'),
    cancelledText: s__('ObservabilityMetrics|Metrics search has been cancelled.'),
  },
  props: {
    metricData: {
      type: Array,
      required: true,
    },
    loading: {
      type: Boolean,
      required: false,
      default: false,
    },
    cancelled: {
      type: Boolean,
      required: false,
      default: false,
    },
    chartInteractive: {
      type: Boolean,
      required: false,
      default: true,
    },
  },
  emits: ['selected'],
  data() {
    return {
      tooltipTitle: '',
      tooltipContent: [],
      selectedTimestamp: null,
      chart: null,
    };
  },
  computed: {
    chartData() {
      return this.metricData.map((metric) => {
        const data = metric.values.map((value) => [
          // note date timestamps are in nano, so converting them to ms here
          convertNanoToMs(value[0]),
          parseFloat(value[1]),
          { ...metric.attributes },
          { traceIds: value[2] || [] },
        ]);
        const hasTraces = (datapointData) => datapointData[3]?.traceIds?.length > 0;

        return {
          name: Object.entries(metric.attributes)
            .map(([k, v]) => `${k}: ${v}`)
            .join(', '),
          data,
          // https://echarts.apache.org/en/option.html#series-line.symbolSize
          symbolSize: (_, p) => {
            if (hasTraces(p.data)) return SYMBOL_SIZE_HIGHLIGHTED;
            return SYMBOL_SIZE_DEFAULT;
          },
          symbol: (_, p) => (hasTraces(p.data) ? BULLSYEYE_ICON_SVG_PATH : 'circle'),
        };
      });
    },
    chartOption() {
      const yUnit = this.metricData?.[0]?.unit;
      const yAxisTitle = this.$options.i18n.yAxisTitle + (yUnit ? ` (${yUnit})` : '');
      return {
        dataZoom: [
          {
            type: 'slider',
          },
        ],
        xAxis: {
          type: 'time',
          name: this.$options.i18n.xAxisTitle,
        },
        yAxis: {
          name: yAxisTitle,
        },
      };
    },
    chartAnnotations() {
      if (this.selectedTimestamp) {
        return [
          {
            min: new Date(this.selectedTimestamp),
            max: new Date(this.selectedTimestamp),
          },
        ];
      }
      return [];
    },
  },
  beforeDestroy() {
    this.chart?.off('mousemove', this.onMouseMove);
  },
  methods: {
    chartCreated(chart) {
      this.chart = chart;

      chart.on('mousemove', this.onMouseMove);
    },
    onMouseMove() {
      this.chart?.getZr().setCursorStyle(this.chartInteractive ? 'pointer' : 'default');
    },
    formatTooltipText({ seriesData }) {
      // reset the tooltip
      this.tooltipTitle = '';
      this.tooltipContent = [];

      if (!Array.isArray(seriesData) || seriesData.length === 0) return;

      if (Array.isArray(seriesData[0].data)) {
        const [dateTime] = seriesData[0].data;
        this.tooltipTitle = formatDate(dateTime, SHORT_DATE_TIME_FORMAT);
      }

      this.tooltipContent = seriesData.map(({ seriesName, color, seriesId, data }) => {
        const [, metric, attr] = data;
        return {
          seriesId,
          label: seriesName,
          attributes: Object.entries(attr).map(([k, v]) => ({ key: k, value: v })),
          value: parseFloat(metric).toFixed(3),
          color,
        };
      });
    },
    chartItemClicked({ chart, params: { data } }) {
      if (!this.chartInteractive || data.name === 'annotations') return;

      const xValue = data[0];
      const visibleSeriesIndices = chart.getModel().getCurrentSeriesIndices();
      const datapoints =
        chart
          .getModel()
          .getSeries()
          .filter((_, index) => visibleSeriesIndices.includes(index))
          .map((series) => {
            const datapoint = series.option.data.find((point) => point[0] === xValue);
            if (datapoint) {
              return {
                seriesName: series.name,
                color: series.option.itemStyle.color,
                timestamp: datapoint[0],
                value: datapoint[1],
                traceIds: datapoint[3]?.traceIds || [],
              };
            }
            return undefined;
          })
          .filter(Boolean) || [];
      this.selectedTimestamp = xValue;
      this.$emit('selected', datapoints);
    },
  },
};
</script>

<template>
  <div ref="chart" class="gl-relative">
    <gl-line-chart
      disabled
      :class="{ 'gl-opacity-3': loading || cancelled }"
      :option="chartOption"
      :data="chartData"
      responsive
      :annotations="chartAnnotations"
      :format-tooltip-text="formatTooltipText"
      @chartItemClicked="chartItemClicked"
      @created="chartCreated"
    >
      <template #tooltip-title>
        <div data-testid="metric-tooltip-title">{{ tooltipTitle }}</div>
      </template>

      <template #tooltip-content>
        <div
          v-for="(metric, index) in tooltipContent"
          :key="`${metric.seriesId}_${index}`"
          data-testid="metric-tooltip-content"
          class="gl-mb-1 gl-flex gl-justify-between gl-text-sm"
        >
          <gl-chart-series-label :color="metric.color" class="gl-mr-7 gl-leading-normal">
            <div v-for="attr in metric.attributes" :key="attr.key + attr.value">
              <span class="gl-font-bold">{{ attr.key }}: </span>{{ attr.value }}
            </div>
          </gl-chart-series-label>

          <div data-testid="metric-tooltip-value" class="gl-font-bold">
            {{ metric.value }}
          </div>
        </div>
      </template>
    </gl-line-chart>

    <div
      v-if="cancelled"
      class="gl-absolute gl-bottom-0 gl-left-0 gl-right-0 gl-top-0 gl-py-13 gl-text-center gl-text-lg gl-font-bold"
    >
      <span>{{ $options.i18n.cancelledText }}</span>
    </div>
  </div>
</template>

<style>
.chart-cancelled-text {
  padding-top: 30%;
}
</style>
