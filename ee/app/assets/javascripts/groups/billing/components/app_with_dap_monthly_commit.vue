<script>
import UltimatePlanCard from './components_with_dap_monthly_commit/ultimate_plan_card.vue';
import DapMonthlyCreditCard from './components_with_dap_monthly_commit/dap_monthly_credit_card.vue';
import CurrentPlanCard from './components_with_dap_monthly_commit/current_plan_card.vue';
import PremiumPlanCard from './components_with_dap_monthly_commit/premium_plan_card.vue';

export default {
  name: 'FreeTrialBillingWithDapMonthlyCommitApp',
  components: {
    CurrentPlanCard,
    DapMonthlyCreditCard,
    PremiumPlanCard,
    UltimatePlanCard,
  },
};
</script>
<template>
  <div class="gl-mx-auto gl-mt-8 gl-max-w-limited">
    <h2 class="gl-heading-2">{{ s__('BillingPlans|Billing') }}</h2>

    <div class="gl-mt-8 gl-flex gl-flex-col gl-gap-5 md:gl-flex-row">
      <current-plan-card />

      <dap-monthly-credit-card />
    </div>

    <h2 class="gl-heading-2 gl-mt-8">{{ s__('BillingPlans|Explore plans') }}</h2>

    <div class="gl-mt-6 gl-flex gl-flex-col gl-gap-5 md:gl-flex-row">
      <premium-plan-card />

      <ultimate-plan-card />
    </div>
  </div>
</template>
