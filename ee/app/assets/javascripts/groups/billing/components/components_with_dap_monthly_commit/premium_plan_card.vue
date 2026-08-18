<script>
import { GlBadge, GlButton, GlCard, GlIcon } from '@gitlab/ui';
import axios from '~/lib/utils/axios_utils';
import { PROMO_URL } from '~/constants';
import { PREMIUM_PLAN_PRICE } from 'ee/billings/constants';
import HandRaiseLeadButton from 'ee/hand_raise_leads/hand_raise_lead/components/hand_raise_lead_button.vue';

export default {
  name: 'PremiumPlanCard',
  components: {
    HandRaiseLeadButton,
    GlBadge,
    GlButton,
    GlCard,
    GlIcon,
  },
  inject: {
    upgradeToPremiumUrl: {
      default: '',
    },
    upgradeToPremiumTrackingUrl: {
      default: '',
    },
    monthlyCommitmentPurchased: {
      default: 0,
    },
  },
  computed: {
    highlightPremium() {
      return !(this.monthlyCommitmentPurchased > 0);
    },
    cardBackgroundColor() {
      return this.highlightPremium ? 'gl-bg-feedback-brand' : 'gl-bg-subtle';
    },
  },
  seeAllFeaturesLink: `${PROMO_URL}/pricing/premium`,
  handRaiseLeadButtonAttributes: {
    class: 'gl-w-full',
    'data-testid': 'premium-plan-talk-to-sales-button',
  },
  handRaiseLeadCtaTracking: {
    action: 'click_button',
    property: 'free_with_dap_monthly_commit',
  },
  methods: {
    triggerTrackCartAbandonment() {
      axios.post(this.upgradeToPremiumTrackingUrl).catch(() => {});
    },
  },
  PREMIUM_PLAN_PRICE,
};
</script>

<template>
  <div class="gl-flex gl-flex-1 gl-flex-col">
    <gl-card
      class="gl-border gl-rounded-b-none gl-p-5"
      :class="cardBackgroundColor"
      body-class="gl-bg-transparent gl-text-subtle"
      header-class="gl-pb-0 gl-mb-0"
    >
      <template #header>
        <div class="gl-flex gl-justify-between">
          <span class="gl-heading-scale-600">{{ s__('BillingPlans|Premium') }}</span>

          <span v-if="highlightPremium" class="gl-self-center">
            <gl-badge variant="info">{{ s__('BillingPlans|Recommended') }}</gl-badge>
          </span>
        </div>
      </template>

      <template #default>
        <p>
          {{
            s__(
              'BillingPlans|For scaling organizations seeking enhanced productivity and collaboration.',
            )
          }}
        </p>
        <p class="gl-mb-0 gl-mt-5 gl-flex">
          <span class="gl-mr-1 gl-mt-1 gl-text-lg gl-font-bold gl-text-default">$</span>
          <span class="gl-heading-scale-600">
            {{ $options.PREMIUM_PLAN_PRICE }}
          </span>
          <span class="gl-ml-3 gl-self-center gl-text-sm">
            {{ s__('BillingPlans|per user/month, billed annually') }}
          </span>
        </p>
      </template>

      <template #footer>
        <gl-button
          v-if="highlightPremium"
          variant="confirm"
          class="gl-w-full"
          data-event-tracking="click_upgrade_to_premium_on_billing_page"
          :href="upgradeToPremiumUrl"
          referrerpolicy="no-referrer-when-downgrade"
          @click="triggerTrackCartAbandonment"
          >{{ s__('BillingPlans|Upgrade to Premium') }}
        </gl-button>
        <hand-raise-lead-button
          v-else
          :button-attributes="$options.handRaiseLeadButtonAttributes"
          :cta-tracking="$options.handRaiseLeadCtaTracking"
          glm-content="billing-group"
          :button-text="s__('BillingPlans|Talk to sales')"
        />
      </template>
    </gl-card>

    <div class="gl-border gl-rounded-b-xl gl-border-t-0 gl-p-6">
      <h3 class="gl-mt-0 gl-text-lg">
        {{ s__('BillingPlans|Everything from Free, plus:') }}
      </h3>

      <ul
        class="gl-mt-5 gl-flex gl-list-none gl-flex-col gl-gap-5 gl-pl-0 gl-text-lg gl-text-subtle"
      >
        <li>
          <gl-icon name="check" variant="info" class="gl-mr-2" />
          <span>{{ s__('BillingPlans|GitLab Duo Agent Platform') }}</span>
        </li>

        <li>
          <gl-icon name="check" variant="info" class="gl-mr-2" />
          <span>{{ s__('BillingPlans|Unlimited licensed users') }}</span>
        </li>

        <li>
          <gl-icon name="check" variant="info" class="gl-mr-2" />
          <span>{{ s__('BillingPlans|10,000 compute minutes per month') }}</span>
        </li>
      </ul>

      <div class="gl-mt-5">
        <gl-button
          :href="$options.seeAllFeaturesLink"
          target="_blank"
          category="tertiary"
          variant="confirm"
          icon="external-link"
        >
          {{ s__('BillingPlans|See all features') }}
        </gl-button>
      </div>
    </div>
  </div>
</template>
