<script>
import {
  DATA_VIZ_BLUE_500,
  DATA_VIZ_GREEN_500,
  DATA_VIZ_ORANGE_300,
} from '@gitlab/ui/src/tokens/build/js/tokens';
import { GlCard } from '@gitlab/ui';
import { GlAreaChart } from '@gitlab/ui/src/charts';
import { minBy } from 'lodash-es';
import {
  newDate,
  getDatesInRange,
  nDaysBefore,
} from '~/lib/utils/datetime/date_calculation_utility';
import { toISODateFormat, formatDate } from '~/lib/utils/datetime/date_format_utility';
import { s__ } from '~/locale';
import HumanTimeframe from '~/vue_shared/components/datetime/human_timeframe.vue';
import { formatNumber } from '../utils';

export default {
  name: 'UsageTrendsChart',
  components: {
    GlCard,
    GlAreaChart,
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
    monthlyCommitmentIsAvailable: {
      type: Boolean,
      required: true,
    },
    monthlyCommitmentDailyUsage: {
      type: Array,
      required: true,
    },
    monthlyCommitmentTotalCredits: {
      type: Number,
      required: true,
    },
    monthlyWaiverIsAvailable: {
      type: Boolean,
      required: true,
    },
    monthlyWaiverDailyUsage: {
      type: Array,
      required: true,
    },
    monthlyWaiverTotalCredits: {
      type: Number,
      required: true,
    },
    overageIsAllowed: {
      type: Boolean,
      required: true,
    },
    overageDailyUsage: {
      type: Array,
      required: true,
    },
  },
  data() {
    return {
      today: toISODateFormat(new Date()),
    };
  },
  computed: {
    monthDates() {
      const startDate = newDate(this.monthStartDate);
      const endDate = newDate(this.monthEndDate);

      return getDatesInRange(startDate, endDate, toISODateFormat);
    },
    monthlyCommitmentData() {
      return this.accumulateValues(this.monthlyCommitmentDailyUsage);
    },
    monthlyCommitmentLimit() {
      return this.monthlyCommitmentTotalCredits;
    },
    monthlyWaiverData() {
      return this.accumulateValues(this.monthlyWaiverDailyUsage);
    },
    monthlyWaiverLimit() {
      return this.monthlyCommitmentLimit + this.monthlyWaiverTotalCredits;
    },
    overageData() {
      return this.accumulateValues(this.overageDailyUsage);
    },
    chartData() {
      return [
        this.monthlyCommitmentIsAvailable && {
          name: s__('UsageBilling|Monthly commitment'),
          stack: 'daily',
          symbolSize: 6,
          showSymbol: false,
          itemStyle: {
            color: DATA_VIZ_BLUE_500,
          },
          areaStyle: {
            color: DATA_VIZ_BLUE_500,
            opacity: 0.2,
          },
          lineStyle: {
            color: DATA_VIZ_BLUE_500,
          },
          data: this.monthlyCommitmentData,
          markLine: {
            lineStyle: {
              type: 'dashed',
              color: DATA_VIZ_BLUE_500,
              width: 2,
            },
            data: [
              {
                yAxis: this.monthlyCommitmentLimit,
                name: s__('UsageBilling|Monthly commitment limit'),
              },
            ],
          },
        },
        this.monthlyWaiverIsAvailable && {
          name: s__('UsageBilling|Monthly waiver'),
          stack: 'daily',
          symbolSize: 6,
          showSymbol: false,
          itemStyle: {
            color: DATA_VIZ_GREEN_500,
          },
          areaStyle: {
            color: DATA_VIZ_GREEN_500,
            opacity: 0.2,
          },
          lineStyle: {
            color: DATA_VIZ_GREEN_500,
          },
          data: this.monthlyWaiverData,
          markLine: {
            lineStyle: {
              type: 'dashed',
              color: DATA_VIZ_GREEN_500,
              width: 2,
            },
            data: [
              { yAxis: this.monthlyWaiverLimit, name: s__('UsageBilling|Monthly waiver limit') },
            ],
          },
        },
        this.overageIsAllowed && {
          name: s__('UsageBilling|On-demand'),
          stack: 'daily',
          symbolSize: 6,
          showSymbol: false,
          itemStyle: {
            color: DATA_VIZ_ORANGE_300,
          },
          areaStyle: {
            color: DATA_VIZ_ORANGE_300,
            opacity: 0.2,
          },
          lineStyle: {
            color: DATA_VIZ_ORANGE_300,
          },
          data: this.overageData,
        },
      ].filter(Boolean);
    },
    chartOptions() {
      return {
        aria: {
          label: {
            description: s__('UsageBilling|GitLab Credits usage trends chart'),
          },
        },
        xAxis: {
          name: s__('UsageBilling|Date'),
          type: 'category',
          axisTick: {
            show: false,
          },
          axisLabel: {
            formatter: this.toShortDateFormat,
          },
        },
        yAxis: {
          name: s__('UsageBilling|Credits'),
          type: 'value',
          // Ensure that y axis cuts off above limits,
          max: (value) => {
            const max = Math.max(this.monthlyCommitmentLimit, this.monthlyWaiverLimit, value.max);
            // adds at least +10 for padding
            return Math.ceil((max + 1) / 10) * 10;
          },
        },
      };
    },
  },
  methods: {
    /** @param { { date: string, creditsUsed: number }[] } data */
    accumulateValues(data) {
      if (!data.length) return [];

      // Ensuring to pick the first date, even if data is not properly ordered
      const firstEventDate = minBy(data, (d) => d.date).date;
      const dateOneDayBeforeFirstEvent = toISODateFormat(nDaysBefore(newDate(firstEventDate), 1));

      // Look-up map for faster access
      const dailyUsageMap = data.reduce((acc, { date, creditsUsed }) => {
        acc[date] = creditsUsed;
        return acc;
      }, {});

      // Walk through dates of the month and accumulate usage data.
      let accumulatedCreditsUsed = 0;
      const accumulatedData = [];

      for (const date of this.monthDates) {
        if (date === dateOneDayBeforeFirstEvent) {
          // Add 0 to the day before the first event, so that the chart doesn't start abruptly.
          // If there is usage on the first day of the month, it should start abruptly.
          accumulatedData.push([date, 0]);
        } else if (date < firstEventDate || date > this.today) {
          // Clear the chart before first usage and after `today`
          accumulatedData.push([date, null]);
        } else {
          // Accumulate usage in active period (`dailyUsageMap[date] || 0` handles no usage plateu)
          accumulatedCreditsUsed += dailyUsageMap[date] || 0;
          accumulatedData.push([date, accumulatedCreditsUsed]);
        }
      }

      return accumulatedData;
    },
    toShortDateFormat(dateString) {
      return formatDate(dateString, 'd mmm', true);
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
          {{ s__('UsageBilling|GitLab Credits usage') }}
        </h2>

        <human-timeframe
          class="gl-text-sm gl-text-subtle"
          :from="monthStartDate"
          :till="monthEndDate"
        />
      </header>

      <gl-area-chart
        class="[&_.gl-legend]:!gl-hidden"
        :data="chartData"
        :option="chartOptions"
        width="auto"
        :include-legend-avg-max="false"
      >
        <template #tooltip-title="{ params }">{{
          params && params.value && toLongDateFormat(params.value)
        }}</template>
        <template #tooltip-value="{ value }">
          <template v-if="value">
            {{ formatNumber(value) }}
          </template>
          <template v-else>—</template>
        </template>
      </gl-area-chart>
    </gl-card>
  </section>
</template>
