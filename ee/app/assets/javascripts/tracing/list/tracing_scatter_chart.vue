<script>
import { GlDiscreteScatterChart } from '@gitlab/ui/src/charts';
import { GL_COLOR_NEUTRAL_200 } from '@gitlab/ui/src/tokens/build/js/tokens';
import { s__, __ } from '~/locale';
import { convertNanoToMs } from '~/lib/utils/datetime_utility';

export default {
  name: 'TracingScatterChart',
  components: {
    GlDiscreteScatterChart,
  },
  i18n: {
    yAxisTitle: s__('Tracing|Duration (ms)'),
    xAxisTitle: s__('Tracing|Time range'),
    noDataText: __('No results found'),
    noDataSubtext: s__('Tracing|Refresh the page, or edit your search filter and try again'),
  },
  props: {
    traces: {
      type: Array,
      required: true,
    },
    height: {
      type: Number,
      required: true,
    },
    rangeMin: {
      type: Date,
      required: false,
      default: null,
    },
    rangeMax: {
      type: Date,
      required: false,
      default: null,
    },
  },
  emits: ['chart-item-out', 'chart-item-over', 'chart-item-selected'],

  computed: {
    chartData() {
      const data = this.traces.map((t) => ({
        value: [t.timestamp, convertNanoToMs(t.duration_nano)],
        traceId: t.trace_id,
        hasError: t.status_code === 'STATUS_CODE_ERROR',
      }));

      return [
        {
          data,
          type: 'scatter',
          itemStyle: {
            color: (p) => (p.data.hasError ? '#ee6666' : p.color),
          },
          symbol: (_, p) => (p.data.hasError ? 'triangle' : 'circle'),
        },
      ];
    },
    chartOption() {
      const title =
        this.traces.length === 0
          ? {
              text: this.$options.i18n.noDataText,
              subtext: this.$options.i18n.noDataSubtext,
              left: 'center',
              top: '40%',
              textStyle: {
                fontSize: 20,
              },
              subtextStyle: {
                fontSize: 15,
              },
            }
          : undefined;
      return {
        title,
        dataZoom: [
          {
            type: 'slider',
          },
        ],
        xAxis: {
          type: 'time',
          max: this.rangeMax,
          min: this.rangeMin,
          axisLine: {
            show: true,
            lineStyle: {
              color: GL_COLOR_NEUTRAL_200,
            },
          },
        },
      };
    },
  },

  methods: {
    chartItemClicked(e) {
      if (e?.params?.data?.traceId) {
        this.$emit('chart-item-selected', { traceId: e.params.data.traceId });
      }
    },
    chartCreated(chart) {
      chart.on('mouseover', (e) => {
        if (e.data?.traceId) {
          this.$emit('chart-item-over', { traceId: e.data.traceId });
        }
      });
      chart.on('mouseout', (e) => {
        if (e.data?.traceId) {
          this.$emit('chart-item-out', { traceId: e.data.traceId });
        }
      });
    },
  },
};
</script>

<template>
  <gl-discrete-scatter-chart
    class="gl-mb-7"
    :option="chartOption"
    :data="chartData"
    :height="height"
    :symbol-size="10"
    disable-tooltip
    :y-axis-title="$options.i18n.yAxisTitle"
    :x-axis-title="$options.i18n.xAxisTitle"
    @created="chartCreated"
    @chartItemClicked="chartItemClicked"
  />
</template>
