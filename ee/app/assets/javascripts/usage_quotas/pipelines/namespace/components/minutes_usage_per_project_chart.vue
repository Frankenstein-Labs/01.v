<script>
import { GlColumnChart } from '@gitlab/ui/src/charts';
import {
  X_AXIS_PROJECT_LABEL,
  X_AXIS_CATEGORY,
  Y_AXIS_PROJECT_LABEL,
  Y_AXIS_SHARED_RUNNER_LABEL,
  NO_CI_MINUTES_MSG,
} from '../constants';

export default {
  name: 'MinutesUsagePerProjectChart',
  X_AXIS_PROJECT_LABEL,
  X_AXIS_CATEGORY,
  Y_AXIS_PROJECT_LABEL,
  Y_AXIS_SHARED_RUNNER_LABEL,
  NO_CI_MINUTES_MSG,
  components: {
    GlColumnChart,
  },
  props: {
    displaySharedRunnerData: {
      type: Boolean,
      required: false,
      default: false,
    },
    projects: {
      type: Array,
      required: true,
    },
  },
  chartOptions: {
    yAxis: {
      axisLabel: {
        formatter: (val) => val,
      },
    },
  },
  computed: {
    chartData() {
      return [{ data: this.projectsData }];
    },
    projectsData() {
      return this.projects.map((cur) =>
        this.displaySharedRunnerData
          ? [cur.project.name, (cur.sharedRunnersDuration / 60).toFixed(2)]
          : [cur.project.name, cur.minutes],
      );
    },
    yAxisTitle() {
      return this.displaySharedRunnerData
        ? this.$options.Y_AXIS_SHARED_RUNNER_LABEL
        : this.$options.Y_AXIS_PROJECT_LABEL;
    },
  },
};
</script>
<template>
  <gl-column-chart
    responsive
    :width="0"
    :bars="chartData"
    :option="$options.chartOptions"
    :y-axis-title="yAxisTitle"
    :x-axis-title="$options.X_AXIS_PROJECT_LABEL"
    :x-axis-type="$options.X_AXIS_CATEGORY"
  />
</template>
