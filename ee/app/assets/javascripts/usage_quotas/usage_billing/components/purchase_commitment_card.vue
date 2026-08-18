<script>
import { GlCard, GlButton, GlSprintf, GlLink } from '@gitlab/ui';
import { PROMO_URL } from '~/constants';
import HandRaiseLeadButton from 'ee/hand_raise_leads/hand_raise_lead/components/hand_raise_lead_button.vue';
import { mergeUrlParams } from '~/lib/utils/url_utility';

export default {
  name: 'PurchaseCommitmentCard',
  components: {
    GlCard,
    GlButton,
    GlSprintf,
    GlLink,
    HandRaiseLeadButton,
  },
  inject: {
    isSaas: { default: false },
    isPaidBasePlan: { default: false },
  },
  props: {
    hasCommitment: {
      required: true,
      type: Boolean,
    },
    purchaseCreditsUrl: {
      required: true,
      type: String,
    },
  },
  pricingLink: `${PROMO_URL}/pricing`,
  handRaiseLeadAttributes: {},
  handRaiseLeadCtaTracking: {
    action: 'click_button',
    label: 'usage_billing_purchase_credits_contact_sales',
  },
  computed: {
    // ref_source tracks navigation context for CDOT conversion attribution
    purchaseCreditsUrlWithRefSource() {
      return mergeUrlParams({ ref_source: 'group_usage_billing_page' }, this.purchaseCreditsUrl);
    },
  },
};
</script>
<template>
  <gl-card class="gl-flex-1" body-class="gl-flex gl-flex-col gl-h-full gl-p-4">
    <template #default>
      <template v-if="hasCommitment">
        <h2 class="gl-heading-scale-400 gl-mb-3">
          {{ s__('UsageBilling|Increase monthly credit commitment') }}
        </h2>
        <p>
          <gl-sprintf
            :message="
              s__(
                'UsageBilling|Increase your commitment to unlock higher discounts. Pool GitLab Credits across your namespace for flexibility and predictable monthly costs. Learn more about %{linkStart}GitLab Credit pricing%{linkEnd}.',
              )
            "
          >
            <template #link="{ content }">
              <gl-link :href="$options.pricingLink" target="_blank">{{ content }}</gl-link>
            </template>
          </gl-sprintf>
        </p>
        <div class="gl-mt-auto gl-flex gl-gap-3">
          <gl-button variant="confirm" :href="purchaseCreditsUrlWithRefSource">
            {{ s__('UsageBilling|Increase commitment') }}
          </gl-button>

          <hand-raise-lead-button
            v-if="isSaas && !isPaidBasePlan"
            glm-content="usage_billing_purchase_credits"
            :button-attributes="$options.handRaiseLeadAttributes"
            :cta-tracking="$options.handRaiseLeadCtaTracking"
            :button-text="s__('UsageBilling|Contact sales')"
          />
        </div>
      </template>

      <template v-else>
        <h2 class="gl-heading-scale-400 gl-mb-3">
          {{ s__('UsageBilling|Save on GitLab Credits with monthly commitment') }}
        </h2>
        <p>
          <gl-sprintf
            :message="
              s__(
                'UsageBilling|Monthly commitments offer significant discounts off list price. Share GitLab Credits across your namespace for flexibility and predictable monthly costs. Learn more about %{linkStart}GitLab Credit pricing%{linkEnd}.',
              )
            "
          >
            <template #link="{ content }">
              <gl-link :href="$options.pricingLink" target="_blank">{{ content }}</gl-link>
            </template>
          </gl-sprintf>
        </p>

        <div class="gl-mt-auto">
          <gl-button variant="confirm" :href="purchaseCreditsUrlWithRefSource">
            {{ s__('UsageBilling|Purchase monthly commitment') }}
          </gl-button>
        </div>
      </template>
    </template>
  </gl-card>
</template>
