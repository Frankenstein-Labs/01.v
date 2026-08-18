<script>
import { GlCard, GlSprintf, GlLink } from '@gitlab/ui';
import { PROMO_URL } from '~/constants';
import { formatNumber } from '../utils';

export default {
  name: 'MonthlyWaiverCard',
  components: {
    GlCard,
    GlSprintf,
    GlLink,
  },
  props: {
    monthlyWaiverCreditsUsed: {
      type: Number,
      required: true,
    },
    monthlyWaiverTotalCredits: {
      type: Number,
      required: true,
    },
  },
  computed: {
    creditsRemaining() {
      return this.monthlyWaiverTotalCredits - this.monthlyWaiverCreditsUsed;
    },
  },
  methods: {
    formatNumber,
  },
  pricingLink: `${PROMO_URL}/pricing`,
};
</script>
<template>
  <gl-card class="gl-flex-1" body-class="gl-p-4">
    <template #header>
      <h2 class="gl-heading-scale-500 gl-mb-0">
        {{ s__('UsageBilling|Monthly Waiver') }}
      </h2>
    </template>
    <template #default>
      <div class="gl-mb-4 gl-text-sm gl-text-subtle">
        {{ s__('UsageBilling|Credits used this month') }}
      </div>
      <div class="gl-heading-scale-600 gl-mb-3" data-testid="monthly-waiver-credits-used">
        {{ formatNumber(monthlyWaiverCreditsUsed) }}
      </div>
      <p class="gl-border-t gl-mb-3 gl-pt-3 gl-text-sm gl-text-subtle">
        <gl-sprintf
          :message="
            s__(
              'UsageBilling|Credits used after all included user credits and monthly commitment pool have been exhausted. Learn about %{linkStart}GitLab Credit pricing%{linkEnd}.',
            )
          "
        >
          <template #link="{ content }">
            <gl-link :href="$options.pricingLink" target="_blank">{{ content }}</gl-link>
          </template>
        </gl-sprintf>
      </p>
      <div
        class="gl-border-t gl-flex gl-flex-row gl-justify-between gl-pt-3 gl-text-sm gl-text-subtle"
      >
        <span>{{ s__('UsageBilling|Monthly Waiver credits remaining') }}</span>
        <span data-testid="monthly-waiver-remaining-credits">
          {{ formatNumber(creditsRemaining) }}
        </span>
      </div>
    </template>
  </gl-card>
</template>
