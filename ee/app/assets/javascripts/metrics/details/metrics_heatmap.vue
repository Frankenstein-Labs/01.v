<script>
import { GlHeatmap } from '@gitlab/ui/src/charts';
import { s__ } from '~/locale';
import { formatDate, convertNanoToMs } from '~/lib/utils/datetime_utility';

// Histogram buckets are in (-Inf, +Inf) interval https://opentelemetry.io/docs/specs/otel/metrics/data-model/#histogram
const DEFAULT_MIN_BUCKET = '-Inf';
export default {
  name: 'MetricsHeatmap',
  components: {
    GlHeatmap,
  },
  i18n: {
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
  computed: {
    heatmapData() {
      // There might be multiple distributions, but for now we only render the first one
      return (
        this.metricData[0]?.data?.[0] || {
          distribution: [],
          buckets: [],
        }
      );
    },
    chartData() {
      return this.heatmapData.distribution.flatMap((arr, bucketIndex) =>
        arr.map((entry, timeIndex) => [
          timeIndex,
          bucketIndex,
          parseFloat(entry[1]), // value
        ]),
      );
    },

    xAxisLabels() {
      /**
       * A distribution is represented as a bi-dimensional array, e.g.
       * { distribution: [
            //bucket 0
            [
              [ts_1, v_a],
              [ts_2, v_b],
              [ts_3, v_c],
            ],
            //bucket 1
            [
              [ts_1, v_d],
              [ts_2, v_e],
              [ts_3, v_f],
            ],
            ... ]}
       * */

      const distribution = this.heatmapData.distribution[0] || [];
      // timestamps are in nano, we need to convert them to ms
      const timeIntervals = distribution.map((entry) => convertNanoToMs(entry[0]));
      return timeIntervals.map((entry) => formatDate(entry, `mmm dd HH:MM`));
    },
    yAxisLabels() {
      return this.heatmapData.buckets;
    },
    chartOption() {
      return {
        tooltip: {
          // show the default tooltip
        },
        xAxis: {
          axisPointer: {
            show: false,
          },
        },
      };
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
    chartItemClicked({ params: { data, color } }) {
      if (!this.chartInteractive) return;

      const [timeIndex, bucketIndex, value] = data;
      const timestampNano = this.heatmapData.distribution[0]?.[timeIndex]?.[0] || 0;
      const prevBucket = this.heatmapData.buckets[bucketIndex - 1] || DEFAULT_MIN_BUCKET;
      const bucket = this.heatmapData.buckets[bucketIndex];

      const datapoint =
        this.heatmapData.distribution[bucketIndex]?.find(([ts]) => ts === timestampNano) || [];
      const traceIds = datapoint[2] || [];

      this.$emit('selected', [
        {
          timestamp: convertNanoToMs(timestampNano),
          value,
          traceIds,
          seriesName: `${prevBucket} - ${bucket}`,
          color,
        },
      ]);
    },
  },
};
</script>

<template>
  <div ref="chart" class="gl-relative">
    <gl-heatmap
      :class="{ 'gl-opacity-3': loading || cancelled }"
      :x-axis-labels="xAxisLabels"
      :y-axis-labels="yAxisLabels"
      :data-series="chartData"
      :option="chartOption"
      :show-tooltip="false"
      responsive
      @chartItemClicked="chartItemClicked"
      @created="chartCreated"
    />
    <div
      v-if="cancelled"
      class="gl-absolute gl-bottom-0 gl-left-0 gl-right-0 gl-top-0 gl-py-2 gl-text-center gl-text-lg gl-font-bold"
    >
      <span>{{ $options.i18n.cancelledText }}</span>
    </div>
  </div>
</template>
