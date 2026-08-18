<script>
import { DATA_VIZ_BLUE_500 } from '@gitlab/ui/src/tokens/build/js/tokens';
import { GlCard, GlSprintf } from '@gitlab/ui';
import { GlStackedColumnChart } from '@gitlab/ui/src/charts';
import { newDate, getDatesInRange } from '~/lib/utils/datetime/date_calculation_utility';
import { toISODateFormat } from '~/lib/utils/datetime/date_format_utility';
import { localeDateFormat } from '~/lib/utils/datetime/locale_dateformat';
import { s__ } from '~/locale';
import { formatNumber } from 'ee/usage_quotas/usage_billing/utils';

export default {
  name: 'CreditsConsumptionChart',
  components: {
    GlCard,
    GlSprintf,
    GlStackedColumnChart,
  },
  props: {
    startDate: {
      type: String,
      required: true,
    },
    endDate: {
      type: String,
      required: true,
    },
    dailyUsage: {
      type: Array,
      required: false,
      default: () => [],
    },
    totalCredits: {
      type: Number,
      required: false,
      default: 0,
    },
  },
  computed: {
    // All dates in the billing period, regardless of whether usage data exists.
    // This ensures the chart shows every day, filling gaps with null.
    allDates() {
      return getDatesInRange(newDate(this.startDate), newDate(this.endDate), toISODateFormat);
    },
    usageByDate() {
      return Object.fromEntries(
        this.dailyUsage.map(({ date, creditsUsed }) => [date, creditsUsed]),
      );
    },
    groupBy() {
      return this.allDates;
    },
    bars() {
      return [
        {
          name: s__('UsageBilling|Total usage'),
          stack: 'usage',
          itemStyle: { color: DATA_VIZ_BLUE_500 },
          data: this.dailyData,
        },
      ];
    },
    dailyData() {
      return this.allDates.map((date) => [date, this.usageByDate[date] ?? null]);
    },
    customPalette() {
      return this.bars.map((bar) => bar.itemStyle.color);
    },
    chartOptions() {
      return {
        xAxis: {
          type: 'category',
          axisTick: { show: false },
          axisLabel: {
            formatter: (value) => localeDateFormat.asDateWithoutYear.format(newDate(value)),
          },
        },
        yAxis: [
          {
            type: 'value',
            axisLabel: { formatter: formatNumber },
          },
        ],
      };
    },
  },
  methods: {
    formatNumber,
  },
};
</script>

<template>
  <gl-card body-class="gl-p-4">
    <div class="gl-mb-4 gl-flex gl-items-start gl-justify-between">
      <div>
        <h2 class="gl-mb-2 gl-mt-0 gl-text-lg gl-font-bold">
          {{ s__('UsageBilling|Total credit consumption') }}
        </h2>
        <span class="gl-text-sm gl-text-subtle">
          <gl-sprintf
            :message="
              n__(
                'UsageBilling|Total: %{count} credit',
                'UsageBilling|Total: %{count} credits',
                totalCredits,
              )
            "
          >
            <template #count>
              <strong>{{ formatNumber(totalCredits) }}</strong>
            </template>
          </gl-sprintf>
        </span>
      </div>
    </div>

    <gl-stacked-column-chart
      :bars="bars"
      :group-by="groupBy"
      :option="chartOptions"
      :custom-palette="customPalette"
      :include-legend-avg-max="false"
      x-axis-type="category"
      :x-axis-title="s__('UsageBilling|Date')"
      :y-axis-title="s__('UsageBilling|GitLab Credits')"
      width="auto"
    >
      <template #tooltip-value="{ value }">
        <template v-if="value[1] != null">{{ formatNumber(value[1]) }}</template>
        <template v-else>—</template>
      </template>
    </gl-stacked-column-chart>
  </gl-card>
</template>
