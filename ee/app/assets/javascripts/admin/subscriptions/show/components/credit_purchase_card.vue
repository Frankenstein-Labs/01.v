<script>
import { GlButton, GlCard, GlLink } from '@gitlab/ui';
import { helpPagePath } from '~/helpers/help_page_helper';
import { PROMO_URL } from '~/constants';

export default {
  name: 'CreditPurchaseCard',
  components: {
    GlButton,
    GlCard,
    GlLink,
  },
  inject: {
    purchaseCreditsPath: {
      default: '',
    },
  },
  GITLAB_CREDITS_DOCS_URL: helpPagePath('subscriptions/gitlab_credits'),
  GITLAB_CREDITS_PRICING_DOCS_URL: `${PROMO_URL}/pricing/?deployment=self-managed-deployment`,
};
</script>

<template>
  <gl-card body-class="gl-p-5">
    <template #header>
      <h3>{{ s__('SuperSonics|GitLab Credits') }}</h3>
    </template>

    <div class="gl-flex gl-flex-col">
      <p>
        {{
          s__(
            'SuperSonics|Purchase monthly credits for your instance and unlock AI capabilities. Volume discounts available.',
          )
        }}
        <gl-link
          :href="$options.GITLAB_CREDITS_DOCS_URL"
          target="_blank"
          data-testid="credit-purchase-card-learn-more-link"
          data-event-tracking="click_learn_more_link_on_sm_credits_card"
          data-event-property="learn_more"
          >{{ s__('SuperSonics|Learn more') }}</gl-link
        >
      </p>

      <div class="gl-flex gl-gap-3">
        <gl-button
          v-if="purchaseCreditsPath"
          variant="confirm"
          data-testid="credit-purchase-card-cta-button"
          data-event-tracking="click_purchase_credits_cta_on_sm_credits_card"
          data-event-property="purchase_credits"
          :href="purchaseCreditsPath"
        >
          {{ s__('SuperSonics|Purchase credits') }}
        </gl-button>
        <gl-button
          category="tertiary"
          data-testid="credit-purchase-card-explore-pricing-button"
          data-event-tracking="click_explore_pricing_cta_on_sm_credits_card"
          data-event-property="explore_pricing"
          :href="$options.GITLAB_CREDITS_PRICING_DOCS_URL"
          target="_blank"
        >
          {{ s__('SuperSonics|Explore pricing') }}
        </gl-button>
      </div>
    </div>
  </gl-card>
</template>
