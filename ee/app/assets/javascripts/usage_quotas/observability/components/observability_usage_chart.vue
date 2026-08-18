<script>
import { GlColumnChart } from '@gitlab/ui/src/charts';
import { formatDate } from '~/lib/utils/datetime/date_format_utility';
import { __ } from '~/locale';
import { numberToHumanSize, numberToMetricPrefix } from '~/lib/utils/number_utils';
import { convertNanoToMs } from '~/lib/utils/datetime_utility';

export default {
  name: 'ObservabilityUsageChart',
  components: {
    GlColumnChart,
  },
  props: {
    usageData: {
      type: Object,
      required: true,
    },
    title: {
      type: String,
      required: true,
    },
  },
  i18n: {
    xAxisTitle: __('Date'),
  },
  computed: {
    chartData() {
      return Object.entries(this.usageData.data).map(([key, distribution]) => {
        return {
          name: key,
          data: distribution.map(([timestampNano, count]) => [
            formatDate(new Date(convertNanoToMs(timestampNano)), 'yyyy-mm-dd'),
            count,
          ]),
        };
      });
    },
  },
  methods: {
    tooltipValue(params) {
      if (this.usageData.data_unit === 'bytes') {
        return numberToHumanSize(params.value);
      }
      return numberToMetricPrefix(params.value, true);
    },
  },
};
</script>
<template>
  <gl-column-chart
    :bars="chartData"
    :y-axis-title="title"
    :x-axis-title="$options.i18n.xAxisTitle"
    x-axis-type="category"
  >
    <template #tooltip-value="params">{{ tooltipValue(params) }}</template>
  </gl-column-chart>
</template>
