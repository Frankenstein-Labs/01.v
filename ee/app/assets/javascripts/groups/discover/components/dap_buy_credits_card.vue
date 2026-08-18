<script>
import { GlButton } from '@gitlab/ui';
import { s__ } from '~/locale';
import { InternalEvents } from '~/tracking';

const trackingMixin = InternalEvents.mixin();

export default {
  name: 'DapBuyCreditsCard',
  components: {
    GlButton,
  },
  mixins: [trackingMixin],
  inject: {
    purchaseCreditsPath: { default: '' },
    creditsDashboardPath: { default: '' },
    hasMonthlyCommit: { default: false },
    creditsGeneralizationUi: { default: false },
  },
  computed: {
    header() {
      if (!this.hasMonthlyCommit && this.creditsGeneralizationUi) {
        return s__('BillingPlans|GitLab Credits');
      }
      return s__('BillingPlans|Save on GitLab Credits with monthly commitment');
    },
    body() {
      if (this.hasMonthlyCommit) {
        if (this.creditsGeneralizationUi) {
          return s__(
            'BillingPlans|You have an active monthly commitment of GitLab Credits shared across your group. You keep these credits when the trial ends.',
          );
        }
        return s__(
          'BillingPlans|Your monthly commitment pool is shared across your group. You keep these credits when the trial ends.',
        );
      }
      if (this.creditsGeneralizationUi) {
        return s__(
          'BillingPlans|Buy monthly credits for AI capabilities, additional compute, and GitLab add-ons. Credits from $1, with volume discounts.',
        );
      }
      return s__(
        'BillingPlans|Monthly commitments offer significant discounts. Pool credits across your namespace for predictable costs, and keep them after your trial ends.',
      );
    },
    secondaryCtaText() {
      if (this.hasMonthlyCommit && this.creditsGeneralizationUi) {
        return s__('BillingPlans|Explore usage');
      }
      return s__('BillingPlans|Manage credits');
    },
    primaryCtaText() {
      return this.hasMonthlyCommit
        ? s__('BillingPlans|Increase credits')
        : s__('BillingPlans|Purchase credits');
    },
    primaryCtaTrackingProperty() {
      return this.hasMonthlyCommit ? 'increase_credits' : 'purchase_credits';
    },
  },
  mounted() {
    this.trackEvent('view_dap_monthly_credit_card');
  },
};
</script>

<template>
  <div class="gl-border gl-flex gl-flex-col gl-rounded-lg gl-bg-subtle gl-p-5 md:gl-p-7">
    <h4 class="gl-heading-4 gl-mb-2">
      {{ header }}
    </h4>

    <p class="gl-mb-4 gl-text-subtle">
      {{ body }}
    </p>

    <div class="gl-mt-auto gl-flex gl-gap-3">
      <gl-button
        :href="purchaseCreditsPath"
        data-testid="dap-credits-primary-cta"
        data-event-tracking="click_cta_on_dap_monthly_credit_card"
        :data-event-property="primaryCtaTrackingProperty"
        >{{ primaryCtaText }}</gl-button
      >
      <gl-button
        v-if="hasMonthlyCommit"
        category="tertiary"
        :href="creditsDashboardPath"
        data-testid="dap-credits-manage-cta"
        data-event-tracking="click_cta_on_dap_monthly_credit_card"
        data-event-property="manage_credits"
        >{{ secondaryCtaText }}</gl-button
      >
    </div>
  </div>
</template>
