<script>
import { GlLineChart } from '@gitlab/ui/src/charts';
import { GlSkeletonLoader } from '@gitlab/ui';
import { isEmpty } from 'lodash-es';
import { s__ } from '~/locale';
import { formatDate } from '~/lib/utils/datetime/date_format_utility';
import { SHORT_DATE_TIME_FORMAT } from '~/observability/constants';
import { convertNanoToMs } from '~/lib/utils/datetime_utility';
import { severityNumberToConfig } from '../utils';

export default {
  components: {
    GlLineChart,
    GlSkeletonLoader,
  },
  i18n: {
    volumeLabel: s__('ObservabilityLogs|Count'),
  },
  props: {
    logsCount: {
      type: Array,
      required: true,
    },
    loading: {
      type: Boolean,
      required: true,
    },
    height: {
      type: Number,
      required: true,
    },
  },
  computed: {
    seriesData() {
      const data = {};

      this.logsCount.forEach(({ time, counts }) => {
        Object.entries(counts).forEach(([severityNumber, count]) => {
          if (!data[severityNumber]) {
            data[severityNumber] = [];
          }
          // note: timestamps are in nano, so converting them to ms here
          data[severityNumber].push([convertNanoToMs(time), count]);
        });
      });

      return data;
    },
    hasData() {
      return !isEmpty(this.seriesData);
    },
    chartData() {
      return Object.entries(this.seriesData).map(([severityNumber, distribution]) => {
        const severityConfig = severityNumberToConfig(severityNumber);
        return {
          name: severityConfig.name,
          data: distribution,
          lineStyle: {
            color: severityConfig.color,
          },
          itemStyle: {
            color: severityConfig.color,
          },
        };
      });
    },
    chartOption() {
      return {
        dataZoom: [
          {
            type: 'slider',
          },
        ],
        xAxis: {
          type: 'time',
          name: '',
        },
        yAxis: {
          name: this.$options.i18n.volumeLabel,
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
};
</script>

<template>
  <div v-if="loading" class="gl-mx-7 gl-my-6">
    <gl-skeleton-loader :lines="5" />
  </div>

  <gl-line-chart
    v-else-if="hasData"
    :data="chartData"
    :height="height"
    :option="chartOption"
    :include-legend-avg-max="false"
    :show-legend="true"
    responsive
    class="gl-my-5"
  >
    <template #tooltip-title="{ params }">{{ tooltipTitle(params) }}</template>
  </gl-line-chart>
</template>
