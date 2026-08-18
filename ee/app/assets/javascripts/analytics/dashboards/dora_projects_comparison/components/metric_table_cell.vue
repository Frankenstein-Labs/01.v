<script>
import { DORA_METRICS } from '~/analytics/shared/constants';
import TrendIndicator from '~/analytics/dashboards/components/trend_indicator.vue';
import { formatMetric } from '~/analytics/dashboards/utils';
import { DORA_TABLE_METRICS } from '../../constants';

const secondsToDays = (seconds) => seconds / 86400;

export default {
  name: 'MetricTableCell',
  components: {
    TrendIndicator,
  },
  props: {
    value: {
      type: [Number, String],
      required: true,
    },
    trend: {
      type: Number,
      required: false,
      default: 0,
    },
    metricType: {
      type: String,
      required: true,
    },
  },
  computed: {
    units() {
      return DORA_TABLE_METRICS[this.metricType].units;
    },
    trendStyle() {
      return DORA_TABLE_METRICS[this.metricType].trendStyle;
    },
    convertedMetric() {
      switch (this.metricType) {
        case DORA_METRICS.LEAD_TIME_FOR_CHANGES:
        case DORA_METRICS.TIME_TO_RESTORE_SERVICE:
          return secondsToDays(this.value);
        case DORA_METRICS.CHANGE_FAILURE_RATE:
          return this.value * 100;
        default:
          return this.value;
      }
    },
    formattedMetric() {
      return formatMetric(this.convertedMetric, this.units);
    },
  },
};
</script>

<template>
  <div>
    {{ formattedMetric }}
    <trend-indicator v-if="trend !== 0" :change="trend" :trend-style="trendStyle" class="gl-ml-3" />
  </div>
</template>
