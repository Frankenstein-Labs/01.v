<script>
import FreeTierTrialApp from './free_tier_trial_app.vue';
import PaidSubscriptionApp from './app.vue';

export default {
  name: 'UsageBillingMetaApp',
  components: {
    FreeTierTrialApp,
    PaidSubscriptionApp,
  },
  inject: {
    isFree: { default: false },
  },
};
</script>
<template>
  <free-tier-trial-app v-if="isFree" />
  <paid-subscription-app v-else />
</template>
