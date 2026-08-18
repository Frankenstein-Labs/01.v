<script>
import { GlBarChart } from '@gitlab/ui/src/charts';
import { s__ } from '~/locale';
import { GL_LIGHT } from '~/constants';
import { getColors } from '../utils/chart';

export default {
  components: {
    GlBarChart,
  },
  props: {
    colorScheme: {
      type: String,
      required: false,
      default: GL_LIGHT,
    },
    data: {
      type: Object,
      required: true,
    },
    path: {
      type: String,
      required: true,
    },
  },
  computed: {
    chartData() {
      return {
        items: [
          {
            value: [this.data.passed, s__('ComplianceReport|Passed')],
            itemStyle: { color: this.colors.blueDataColor },
          },
          {
            value: [this.data.pending, s__('ComplianceReport|Pending')],
            itemStyle: { color: this.colors.orangeDataColor },
          },
          {
            value: [this.data.failed, s__('ComplianceReport|Failed')],
            itemStyle: { color: this.colors.magentaDataColor },
          },
        ],
      };
    },
    colors() {
      return getColors(this.colorScheme);
    },
  },
  methods: {
    handleChartClick() {
      this.$router.push({ name: this.path });
    },
  },
};
</script>

<template>
  <!-- axis titles intentionally blank -->
  <gl-bar-chart
    x-axis-title=""
    y-axis-title=""
    height="auto"
    :data="chartData"
    @chartItemClicked="handleChartClick"
  />
</template>
