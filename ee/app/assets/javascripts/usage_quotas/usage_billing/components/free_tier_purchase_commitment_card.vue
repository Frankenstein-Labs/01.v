<script>
import { GlButton, GlCard, GlLink } from '@gitlab/ui';
import { s__ } from '~/locale';
import { helpPagePath } from '~/helpers/help_page_helper';

export default {
  name: 'FreeTierPurchaseCommitmentCard',
  components: {
    GlButton,
    GlCard,
    GlLink,
  },
  inject: {
    purchaseCreditsPath: {},
    creditsGeneralizationUi: { default: false },
  },
  computed: {
    headerText() {
      return this.creditsGeneralizationUi
        ? s__('AiPowered|Buy GitLab Credits')
        : s__('AiPowered|Save on GitLab Credits with monthly commitments');
    },
    bodyText() {
      return this.creditsGeneralizationUi
        ? s__(
            'AiPowered|Buy monthly credits for AI capabilities, additional compute, and GitLab add-ons. Credits from $1, with volume discounts.',
          )
        : s__(
            'AiPowered|Monthly commitments offer significant discounts off list price. Pool GitLab Credits across your namespace for flexibility and predictable monthly costs.',
          );
    },
  },
  GITLAB_CREDITS_DOCS_URL: helpPagePath('subscriptions/gitlab_credits'),
};
</script>
<template>
  <gl-card class="gl-flex-1" header-class="gl-heading-scale-400">
    <template #header>
      <div class="gl-flex gl-items-center gl-justify-between">
        <span>{{ headerText }}</span>
        <gl-button
          v-if="creditsGeneralizationUi"
          :href="purchaseCreditsPath"
          size="small"
          variant="confirm"
          data-event-tracking="click_purchase_credits_cta_active_trial"
        >
          {{ s__('AiPowered|Purchase credits') }}
        </gl-button>
      </div>
    </template>
    <div class="gl-flex gl-h-full gl-flex-col gl-justify-between">
      <div>
        {{ bodyText }}
        <gl-link
          v-if="creditsGeneralizationUi"
          :href="$options.GITLAB_CREDITS_DOCS_URL"
          target="_blank"
          data-event-tracking="click_learn_more_link_free_tier_purchase_commitment"
        >
          {{ __('Learn more') }}
        </gl-link>
      </div>
      <div v-if="!creditsGeneralizationUi" class="gl-pt-5">
        <gl-button
          :href="purchaseCreditsPath"
          variant="confirm"
          data-event-tracking="click_purchase_credits_cta_active_trial"
        >
          {{ s__('AiPowered|Purchase credits') }}
        </gl-button>
        <gl-button
          :href="$options.GITLAB_CREDITS_DOCS_URL"
          category="tertiary"
          variant="confirm"
          data-event-tracking="click_learn_more_link_free_tier_purchase_commitment"
        >
          {{ __('Learn more') }}
        </gl-button>
      </div>
    </div>
  </gl-card>
</template>
