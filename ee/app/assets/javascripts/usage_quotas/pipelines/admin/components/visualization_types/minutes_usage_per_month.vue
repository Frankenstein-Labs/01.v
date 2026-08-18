<script>
import { GlTab, GlTabs } from '@gitlab/ui';
import { GlAreaChart } from '@gitlab/ui/src/charts';
import { __, s__ } from '~/locale';
import NoMinutesAlert from '../shared/no_minutes_alert.vue';

const X_AXIS_CATEGORY = 'category';

export default {
  name: 'MinutesUsagePerMonth',
  components: {
    GlAreaChart,
    GlTab,
    GlTabs,
    NoMinutesAlert,
  },
  props: {
    usageData: {
      type: Array,
      required: true,
    },
  },
  computed: {
    formattedData() {
      return [
        {
          data: this.sortedUsageData,
          name: s__('UsageQuota|Hosted runner pipeline duration by month'),
        },
      ];
    },
    sortedUsageData() {
      return this.usageData
        .slice()
        .sort((a, b) => new Date(a.billingMonthIso8601) - new Date(b.billingMonthIso8601))
        .map((el) => [el.billingMonth, el.computeMinutesUsage]);
    },
    emptyData() {
      return this.usageData.length === 0;
    },
  },
  chartOptions: {
    xAxis: {
      name: __('Month'),
      type: X_AXIS_CATEGORY,
    },
    yAxis: {
      name: __('Compute minutes'),
      axisLabel: {
        formatter: (val) => val,
      },
    },
  },
};
</script>
<template>
  <gl-tabs>
    <gl-tab :title="s__('UsageQuota|Compute usage')">
      <no-minutes-alert v-if="emptyData" />
      <gl-area-chart
        v-else
        :data="formattedData"
        :option="$options.chartOptions"
        responsive
        :width="0"
      />
    </gl-tab>
  </gl-tabs>
</template>
