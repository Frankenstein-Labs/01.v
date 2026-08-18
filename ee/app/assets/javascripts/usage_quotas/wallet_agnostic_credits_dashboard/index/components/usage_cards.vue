<script>
import { GlCard } from '@gitlab/ui';
import { formatDate } from '~/lib/utils/datetime/date_format_utility';
import { formatNumber } from '../../../usage_billing/utils';

export default {
  name: 'UsageCards',
  components: {
    GlCard,
  },
  props: {
    totalUsedCredits: {
      type: Number,
      required: true,
    },
    activeUsersCount: {
      type: Number,
      required: true,
    },
    dailyAverage: {
      type: Number,
      required: true,
    },
    peakDayUsage: {
      type: Number,
      required: false,
      default: 0,
    },
    peakDayDate: {
      type: String,
      required: false,
      default: '',
    },
  },
  methods: {
    formatNumber,
    formatDate,
  },
};
</script>
<template>
  <div class="gl-grid gl-grid-cols-1 gl-gap-4 @md/panel:gl-grid-cols-2 @lg/panel:gl-grid-cols-4">
    <gl-card class="gl-flex-1" data-testid="total-usage-card">
      <template #header>
        <h2 class="gl-heading-scale-500 gl-mb-0">
          {{ s__('UsageBilling|Total usage') }}
        </h2>
      </template>
      <template #default>
        <div class="gl-flex gl-flex-col">
          <span class="gl-heading-scale-600 gl-font-bold">
            {{ formatNumber(totalUsedCredits) }}
          </span>
          <span class="gl-text-sm gl-text-subtle">
            {{ s__('UsageBilling|in selected date range') }}
          </span>
        </div>
      </template>
    </gl-card>
    <gl-card class="gl-flex-1" data-testid="active-users-card">
      <template #header>
        <h2 class="gl-heading-scale-500 gl-mb-0">
          {{ s__('UsageBilling|Active users') }}
        </h2>
      </template>
      <template #default>
        <div class="gl-flex gl-flex-col">
          <span class="gl-heading-scale-600 gl-font-bold">
            {{ formatNumber(activeUsersCount) }}
          </span>
          <span class="gl-text-sm gl-text-subtle">
            {{ s__('UsageBilling|in selected date range') }}
          </span>
        </div>
      </template>
    </gl-card>
    <gl-card class="gl-flex-1" data-testid="daily-average-card">
      <template #header>
        <h2 class="gl-heading-scale-500 gl-mb-0">
          {{ s__('UsageBilling|Daily average') }}
        </h2>
      </template>
      <template #default>
        <div class="gl-flex gl-flex-col">
          <span class="gl-heading-scale-600 gl-font-bold">
            {{ formatNumber(dailyAverage) }}
          </span>
          <span class="gl-text-sm gl-text-subtle">
            {{ s__('UsageBilling|Credits per day') }}
          </span>
        </div>
      </template>
    </gl-card>
    <gl-card class="gl-flex-1" data-testid="peak-day-usage-card">
      <template #header>
        <h2 class="gl-heading-scale-500 gl-mb-0">
          {{ s__('UsageBilling|Peak day usage') }}
        </h2>
      </template>
      <template #default>
        <div class="gl-flex gl-flex-col">
          <span class="gl-heading-scale-600 gl-font-bold">
            {{ formatNumber(peakDayUsage) }}
          </span>
          <span v-if="peakDayDate" class="gl-text-sm gl-text-subtle">
            {{ formatDate(peakDayDate, 'mmm d') }}
          </span>
        </div>
      </template>
    </gl-card>
  </div>
</template>
