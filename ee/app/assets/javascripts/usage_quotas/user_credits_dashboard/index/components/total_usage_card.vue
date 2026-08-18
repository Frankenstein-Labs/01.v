<script>
import { GlCard } from '@gitlab/ui';
import HumanTimeframe from '~/vue_shared/components/datetime/human_timeframe.vue';
import { formatNumber } from '../../../usage_billing/utils';

export default {
  name: 'TotalUsageCard',
  components: {
    GlCard,
    HumanTimeframe,
  },
  props: {
    creditsUsed: {
      type: Number,
      required: false,
      default: 0,
    },
    startDate: {
      type: String,
      required: false,
      default: null,
    },
    endDate: {
      type: String,
      required: false,
      default: null,
    },
  },
  computed: {
    formattedCreditsUsed() {
      return formatNumber(this.creditsUsed);
    },
  },
};
</script>

<template>
  <gl-card data-testid="total-usage-card" class="gl-max-w-1/2 gl-flex-1" body-class="gl-p-4">
    <div class="gl-heading-scale-600 gl-mb-3 gl-font-bold" data-testid="billing-period-credits">
      {{ formattedCreditsUsed }}
    </div>
    <div class="gl-font-bold">
      <p class="gl-my-0">{{ s__('UsageBilling|Credits used in this billing period') }}</p>
      <p v-if="startDate && endDate" class="gl-my-0 gl-text-sm gl-text-subtle">
        <human-timeframe :from="startDate" :till="endDate" />
      </p>
    </div>
  </gl-card>
</template>
