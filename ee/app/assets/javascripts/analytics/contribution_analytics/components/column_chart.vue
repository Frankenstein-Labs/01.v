<script>
import { GlColumnChart } from '@gitlab/ui/src/charts';
import { getDataZoomOption } from '~/analytics/shared/utils';
import { truncateWidth } from '~/lib/utils/text_utility';

import {
  CHART_HEIGHT,
  CHART_X_AXIS_NAME_TOP_PADDING,
  CHART_X_AXIS_ROTATE,
  INNER_CHART_HEIGHT,
} from '../constants';

export default {
  name: 'ContributionAnalyticsColumnChart',
  components: {
    GlColumnChart,
  },
  props: {
    chartData: {
      type: Array,
      required: true,
    },
    xAxisTitle: {
      type: String,
      required: false,
      default: '',
    },
    yAxisTitle: {
      type: String,
      required: false,
      default: '',
    },
  },
  data() {
    return {
      width: 0,
      height: CHART_HEIGHT,
    };
  },
  computed: {
    dataZoomOption() {
      const dataZoom = [
        {
          type: 'slider',
          bottom: 10,
          start: 0,
        },
      ];

      return {
        dataZoom: getDataZoomOption({ totalItems: this.chartData.length, dataZoom }),
      };
    },
    chartOptions() {
      return {
        ...this.dataZoomOption,
        height: INNER_CHART_HEIGHT,
        xAxis: {
          axisLabel: {
            rotate: CHART_X_AXIS_ROTATE,
            formatter(value) {
              return truncateWidth(value);
            },
          },
          nameTextStyle: {
            padding: [CHART_X_AXIS_NAME_TOP_PADDING, 0, 0, 0],
          },
        },
      };
    },
    seriesData() {
      return [{ name: 'full', data: this.chartData }];
    },
  },
};
</script>

<template>
  <gl-column-chart
    ref="columnChart"
    v-bind="$attrs"
    :width="width"
    :height="height"
    :bars="seriesData"
    :responsive="true"
    :x-axis-title="xAxisTitle"
    :y-axis-title="yAxisTitle"
    x-axis-type="category"
    :option="chartOptions"
  />
</template>
