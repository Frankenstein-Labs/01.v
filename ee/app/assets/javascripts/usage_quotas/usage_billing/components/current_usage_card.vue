<script>
import { GlCard, GlProgressBar, GlSprintf } from '@gitlab/ui';
import { getDayDifference } from '~/lib/utils/datetime/date_calculation_utility';
import { newDate } from '~/lib/utils/datetime_utility';
import { formatNumber } from '../utils';

export default {
  name: 'CurrentUsageCard',
  components: {
    GlCard,
    GlProgressBar,
    GlSprintf,
  },
  props: {
    poolCreditsUsed: {
      type: Number,
      required: true,
    },
    poolTotalCredits: {
      type: Number,
      required: true,
    },
    monthEndDate: {
      type: String,
      required: true,
    },
  },
  computed: {
    usagePercentage() {
      if (this.poolTotalCredits === 0) return 0;
      return Number(((this.poolCreditsUsed / this.poolTotalCredits) * 100).toFixed(1));
    },
    poolCreditsRemaining() {
      return this.poolTotalCredits - this.poolCreditsUsed;
    },
    daysOfMonthRemaining() {
      const today = new Date();
      const endDate = newDate(this.monthEndDate);
      const diffDays = getDayDifference(today, endDate);

      return Math.max(0, diffDays);
    },
  },
  methods: {
    formatNumber,
  },
  totalCreditsSeparator: '/ ',
};
</script>
<template>
  <gl-card class="gl-flex-1" body-class="gl-p-4">
    <template #header>
      <h2 class="gl-heading-scale-500 gl-mb-0">
        {{ s__('UsageBilling|Monthly Committed Pool') }}
      </h2>
    </template>
    <template #default>
      <div class="gl-mb-4 gl-text-sm gl-text-subtle" data-testid="monthly-commitment-subtitle">
        <gl-sprintf
          :message="
            n__(
              'UsageBilling|Credits used this month, resets in %{days} day',
              'UsageBilling|Credits used this month, resets in %{days} days',
              daysOfMonthRemaining,
            )
          "
        >
          <template #days>{{ daysOfMonthRemaining }}</template>
        </gl-sprintf>
      </div>
      <div class="gl-mb-3 gl-flex">
        <span class="gl-heading-scale-600 gl-mr-3 gl-font-bold" data-testid="total-credits-used">
          {{ formatNumber(poolCreditsUsed) }}
        </span>
        <span
          class="gl-heading-scale-600 gl-font-bold gl-text-subtle"
          data-testid="pool-total-credits"
        >
          {{ $options.totalCreditsSeparator }}
          {{ formatNumber(poolTotalCredits) }}
        </span>
      </div>
      <gl-progress-bar :value="usagePercentage" variant="primary" class="gl-mb-3 gl-mt-1 gl-h-3" />
      <div class="gl-flex gl-flex-col gl-gap-3 gl-text-sm">
        <div class="gl-flex gl-flex-row gl-justify-between">
          <span data-testid="percentage-utilized" class="gl-text-subtle">
            <gl-sprintf
              :message="s__('UsageBilling|%{percentage}%{percentSymbol} of credits used')"
            >
              <template #percentage>{{ usagePercentage }}</template>
              <template #percentSymbol>%</template>
            </gl-sprintf>
          </span>

          <span data-testid="pool-credits-remaining" class="gl-text-subtle">
            <gl-sprintf
              :message="
                n__(
                  'UsageBilling|%{poolCreditsRemaining} credit remaining',
                  'UsageBilling|%{poolCreditsRemaining} credits remaining',
                  poolCreditsRemaining,
                )
              "
            >
              <template #poolCreditsRemaining>{{ formatNumber(poolCreditsRemaining) }}</template>
            </gl-sprintf>
          </span>
        </div>
        <p class="gl-border-t gl-mb-0 gl-pt-3 gl-text-sm gl-text-subtle">
          <gl-sprintf
            :message="
              s__('UsageBilling|Shared pool of credits available to all users in the subscription.')
            "
          />
        </p>
      </div>
    </template>
  </gl-card>
</template>
