<script>
import { GlLineChart, GlColumnChart } from '@gitlab/ui/src/charts';
import { GlSkeletonLoader } from '@gitlab/ui';
import {
  GL_COLOR_DATA_ORANGE_300,
  GL_COLOR_DATA_GREEN_400,
  GL_COLOR_DATA_BLUE_500,
} from '@gitlab/ui/src/tokens/build/js/tokens';
import { s__, sprintf } from '~/locale';
import { formatDate } from '~/lib/utils/datetime/date_format_utility';
import { SHORT_DATE_TIME_FORMAT } from '~/observability/constants';
import { convertNanoToMs } from '~/lib/utils/datetime_utility';

const intervalToTimestamp = (interval) => new Date(interval * 1000);
const toFixed = (n) => parseFloat(n).toFixed(2);

const buildVolumeRateData = ({ interval, trace_rate: traceRate = 0 }, volumeData) => {
  volumeData.push([intervalToTimestamp(interval), toFixed(traceRate)]);
};

const buildErrorRateData = ({ interval, error_rate: errorRate = 0 }, errorData) => {
  errorData.push([intervalToTimestamp(interval), toFixed(errorRate)]);
};

const buildDurationData = (
  {
    interval,
    p90_duration_nano: p90 = 0,
    p95_duration_nano: p95 = 0,
    p75_duration_nano: p75 = 0,
    p50_duration_nano: p50 = 0,
  },
  durationData,
) => {
  const timestamp = intervalToTimestamp(interval);
  durationData.p90.push([timestamp, toFixed(convertNanoToMs(p90))]);
  durationData.p95.push([timestamp, toFixed(convertNanoToMs(p95))]);
  durationData.p75.push([timestamp, toFixed(convertNanoToMs(p75))]);
  durationData.p50.push([timestamp, toFixed(convertNanoToMs(p50))]);
};

export default {
  name: 'TracingAnalytics',
  components: {
    GlLineChart,
    GlColumnChart,
    GlSkeletonLoader,
  },
  i18n: {
    durationLabel: s__('Tracing|Duration (ms)'),
    errorRateLabel: sprintf(s__('Tracing|Error rate (%%)')),
    volumeLabel: s__('Tracing|Request rate (req/s)'),
  },
  props: {
    analytics: {
      type: Array,
      required: true,
    },
    loading: {
      type: Boolean,
      required: true,
    },
    chartHeight: {
      type: Number,
      required: true,
    },
  },
  computed: {
    seriesData() {
      const errorRateData = [];
      const volumeRateData = [];
      const durationData = { p90: [], p95: [], p75: [], p50: [] };

      this.analytics.forEach((metric) => {
        buildVolumeRateData(metric, volumeRateData);
        buildErrorRateData(metric, errorRateData);
        buildDurationData(metric, durationData);
      });
      return {
        errorRateData,
        durationData,
        volumeRateData,
      };
    },
    errorRateChartData() {
      return [
        {
          type: 'line',
          name: this.$options.i18n.errorRateLabel,
          data: this.seriesData.errorRateData,
          lineStyle: {
            color: '#F15642',
          },
          itemStyle: {
            color: '#F15642',
          },
        },
      ];
    },
    volumeRateChartData() {
      return [
        {
          data: this.seriesData.volumeRateData,
          name: this.$options.i18n.volumeLabel,
        },
      ];
    },
    durationChartData() {
      return [
        {
          name: 'p90',
          data: this.seriesData.durationData.p90,
          lineStyle: { color: GL_COLOR_DATA_ORANGE_300 },
          itemStyle: { color: GL_COLOR_DATA_ORANGE_300 },
        },
        {
          name: 'p95',
          data: this.seriesData.durationData.p95,
          lineStyle: { color: GL_COLOR_DATA_GREEN_400 },
          itemStyle: { color: GL_COLOR_DATA_GREEN_400 },
        },
        {
          name: 'p75',
          data: this.seriesData.durationData.p75,
          lineStyle: { color: '#3F8EAD' },
          itemStyle: { color: '#3F8EAD' },
        },
        {
          name: 'p50',
          data: this.seriesData.durationData.p50,
          lineStyle: { color: GL_COLOR_DATA_BLUE_500 },
          itemStyle: { color: GL_COLOR_DATA_BLUE_500 },
        },
      ];
    },
    durationChartOption() {
      return {
        xAxis: {
          type: 'time',
          name: this.$options.i18n.durationLabel,
        },
        yAxis: {
          name: '',
        },
      };
    },
    volumeChartOption() {
      return {
        xAxis: {
          type: 'time',
          name: this.$options.i18n.volumeLabel,
        },
        yAxis: {
          name: '',
          axisLabel: {
            formatter: '{value}',
          },
        },
      };
    },
    errorChartOption() {
      return {
        xAxis: {
          type: 'time',
          name: this.$options.i18n.errorRateLabel,
        },
        yAxis: {
          name: '',
          axisLabel: {
            formatter: '{value}',
          },
        },
      };
    },
  },
  methods: {
    tooltipTitle(params) {
      const seriesData = params?.seriesData || [];
      const dataPoints = seriesData[0]?.data || [];
      const timestamp = dataPoints[0];
      return timestamp ? formatDate(timestamp, SHORT_DATE_TIME_FORMAT) : '';
    },
  },

  SKELETON_CLASS: 'analytics-chart gl-mx-7 gl-my-4',
  CONTAINER_CLASS: 'gl-flex gl-flex-row gl-mb-6',
};
</script>

<template>
  <div v-if="loading" :class="$options.CONTAINER_CLASS">
    <div :class="$options.SKELETON_CLASS"><gl-skeleton-loader :lines="5" /></div>
    <div :class="$options.SKELETON_CLASS"><gl-skeleton-loader :lines="5" /></div>
    <div :class="$options.SKELETON_CLASS"><gl-skeleton-loader :lines="5" /></div>
  </div>
  <div v-else-if="analytics.length" :class="$options.CONTAINER_CLASS">
    <div class="analytics-chart">
      <gl-column-chart
        :bars="volumeRateChartData"
        :height="chartHeight"
        :option="volumeChartOption"
        responsive
        :x-axis-title="$options.i18n.volumeLabel"
        x-axis-type="time"
        y-axis-title=""
      >
        <template #tooltip-title="{ params }">{{ tooltipTitle(params) }}</template>
      </gl-column-chart>
    </div>
    <div class="analytics-chart">
      <gl-line-chart
        :data="errorRateChartData"
        :height="chartHeight"
        :include-legend-avg-max="false"
        :option="errorChartOption"
        :show-legend="false"
        responsive
      >
        <template #tooltip-title="{ params }">{{ tooltipTitle(params) }}</template>
      </gl-line-chart>
    </div>
    <div class="analytics-chart">
      <gl-line-chart
        :data="durationChartData"
        :height="chartHeight"
        :include-legend-avg-max="false"
        :option="durationChartOption"
        responsive
      >
        <template #tooltip-title="{ params }">{{ tooltipTitle(params) }}</template>
      </gl-line-chart>
    </div>
  </div>
</template>

<style>
.analytics-chart {
  flex: 1;
}
</style>
