<script>
import {
  DATA_VIZ_GREEN_500,
  DATA_VIZ_BLUE_500,
  DATA_VIZ_BLUE_950,
  DATA_VIZ_ORANGE_300,
} from '@gitlab/ui/src/tokens/build/js/tokens';
import { GlCard } from '@gitlab/ui';
import { GlStackedColumnChart } from '@gitlab/ui/src/charts';
import { newDate, getDatesInRange } from '~/lib/utils/datetime/date_calculation_utility';
import { toISODateFormat, formatDate } from '~/lib/utils/datetime/date_format_utility';
import { s__ } from '~/locale';
import HumanTimeframe from '~/vue_shared/components/datetime/human_timeframe.vue';
import { formatNumber } from '../utils';

export default {
  name: 'UsageOverviewChart',
  components: {
    GlCard,
    GlStackedColumnChart,
    HumanTimeframe,
  },
  props: {
    monthStartDate: {
      type: String,
      required: true,
    },
    monthEndDate: {
      type: String,
      required: true,
    },
    commitmentDailyUsage: {
      type: Array,
      required: true,
    },
    waiverDailyUsage: {
      type: Array,
      required: true,
    },
    overageDailyUsage: {
      type: Array,
      required: true,
    },
    paidTierTrialDailyUsage: {
      type: Array,
      required: true,
    },
    usersUsageDailyUsage: {
      type: Array,
      required: true,
    },
  },
  computed: {
    monthDates() {
      const startDate = newDate(this.monthStartDate);
      const endDate = newDate(this.monthEndDate);
      return getDatesInRange(startDate, endDate, toISODateFormat);
    },
    bars() {
      return [
        this.produceDataSeries({
          name: s__('UsageBilling|Trial'),
          stack: 'daily',
          itemStyle: {
            color: DATA_VIZ_GREEN_500,
          },
          data: this.paidTierTrialDailyUsage,
        }),
        this.produceDataSeries({
          name: s__('UsageBilling|Included credits'),
          stack: 'daily',
          itemStyle: {
            color: DATA_VIZ_BLUE_950,
          },
          data: this.usersUsageDailyUsage,
        }),
        this.produceDataSeries({
          name: s__('UsageBilling|Monthly commitment'),
          stack: 'daily',
          itemStyle: {
            color: DATA_VIZ_BLUE_500,
          },
          data: this.commitmentDailyUsage,
        }),
        this.produceDataSeries({
          name: s__('UsageBilling|Monthly waiver'),
          stack: 'daily',
          itemStyle: {
            color: DATA_VIZ_GREEN_500,
          },
          data: this.waiverDailyUsage,
        }),
        this.produceDataSeries({
          name: s__('UsageBilling|On-demand'),
          stack: 'daily',
          itemStyle: {
            color: DATA_VIZ_ORANGE_300,
          },
          data: this.overageDailyUsage,
        }),
      ].filter(Boolean);
    },
    customPalette() {
      return this.bars.map((barData) => barData.itemStyle.color);
    },
    chartOptions() {
      return {
        aria: {
          label: {
            description: s__('UsageBilling|Daily GitLab Credits usage chart'),
          },
        },
        xAxis: {
          type: 'category',
          axisTick: {
            show: false,
          },
          axisLabel: {
            formatter: this.toDateOfMonthFormat,
          },
        },
        yAxis: [
          {
            type: 'value',
            name: s__('UsageBilling|GitLab Credits'),
            axisLabel: {
              formatter: formatNumber,
            },
          },
        ],
      };
    },
  },
  methods: {
    produceDataSeries(config) {
      if (!this.hasData(config.data)) return null;

      return {
        ...config,
        data: this.buildDailyDataArray(config.data),
      };
    },
    hasData(data) {
      if (!data) return false;
      return data.some(({ creditsUsed }) => creditsUsed > 0);
    },
    buildDailyDataArray(dailyUsage) {
      const dailyUsageMap = dailyUsage.reduce((acc, { date, creditsUsed }) => {
        acc[date] = creditsUsed;
        return acc;
      }, {});

      return this.monthDates.map((date) => {
        return [date, dailyUsageMap[date] ?? null];
      });
    },
    toDateOfMonthFormat(dateString) {
      return String(newDate(dateString).getDate()).padStart(2, '0');
    },
    toLongDateFormat(dateString) {
      return formatDate(dateString, 'd mmmm', true);
    },
    formatNumber,
  },
};
</script>
<template>
  <section>
    <gl-card class="gl-flex-1 gl-bg-transparent" body-class="gl-p-5">
      <header class="gl-mb-3">
        <h2 class="gl-heading-scale-300 gl-mb-1 gl-font-heading">
          {{ s__('UsageBilling|Daily GitLab Credits usage') }}
        </h2>

        <human-timeframe
          class="gl-text-sm gl-text-subtle"
          :from="monthStartDate"
          :till="monthEndDate"
        />
      </header>

      <gl-stacked-column-chart
        :bars="bars"
        :group-by="monthDates"
        :option="chartOptions"
        :custom-palette="customPalette"
        :include-legend-avg-max="false"
        :x-axis-title="s__('UsageBilling|Date')"
        x-axis-type="category"
        :y-axis-title="s__('UsageBilling|GitLab Credits')"
        width="auto"
      >
        <template #tooltip-title="{ params }">{{
          params && params.value && toLongDateFormat(params.value)
        }}</template>

        <template #tooltip-value="{ value }">
          <template v-if="value[1]">
            {{ formatNumber(value[1]) }}
          </template>
          <template v-else>—</template>
        </template>
      </gl-stacked-column-chart>
    </gl-card>
  </section>
</template>
