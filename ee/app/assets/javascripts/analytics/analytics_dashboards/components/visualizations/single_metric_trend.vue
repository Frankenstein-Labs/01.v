<script>
import { GlSparklineChart, GlSingleStat } from '@gitlab/ui/src/charts';
import { humanizeDisplayUnit, calculateDecimalPlaces } from './utils';

export default {
  name: 'SingleMetricTrend',
  components: {
    GlSingleStat,
    GlSparklineChart,
  },
  props: {
    data: {
      type: Object,
      required: false,
      default: () => ({
        value: 0,
        trend: [],
      }),
    },
    options: {
      type: Object,
      required: false,
      default: () => ({}),
    },
  },
  computed: {
    title() {
      return this.options.title ?? '';
    },
    decimalPlaces() {
      // Only set the decimals places if this has data
      const {
        data: { value },
        options: { decimalPlaces },
      } = this;
      return calculateDecimalPlaces({ data: value, decimalPlaces });
    },
    humanizedUnit() {
      const {
        data: { value },
        options: { unit },
      } = this;
      return humanizeDisplayUnit({ data: value, unit });
    },
    hasTrend() {
      const { trend = [] } = this.data;
      return trend.length > 0;
    },
  },
};
</script>
<template>
  <div class="gl-flex gl-h-full gl-flex-col gl-justify-center gl-py-5">
    <div class="gl-text-left">
      <gl-single-stat
        :value="data.value"
        :title="title"
        :meta-text="options.metaText"
        :meta-icon="options.metaIcon"
        :title-icon="options.metricIcon"
        :unit="humanizedUnit"
        :animation-decimal-places="decimalPlaces"
        variant="neutral"
        should-animate
        use-delimiters
      />
    </div>
    <div v-if="hasTrend">
      <gl-sparkline-chart :data="data.trend" />
    </div>
  </div>
</template>
