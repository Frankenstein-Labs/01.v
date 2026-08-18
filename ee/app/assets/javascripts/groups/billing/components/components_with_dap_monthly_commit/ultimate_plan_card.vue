<script>
import { GlButton, GlCard, GlIcon } from '@gitlab/ui';
import axios from '~/lib/utils/axios_utils';
import { PROMO_URL } from '~/constants';
import HandRaiseLeadButton from 'ee/hand_raise_leads/hand_raise_lead/components/hand_raise_lead_button.vue';

export default {
  name: 'UltimatePlanCard',
  components: {
    HandRaiseLeadButton,
    GlButton,
    GlCard,
    GlIcon,
  },
  inject: {
    upgradeToUltimateUrl: {
      default: '',
    },
    upgradeToUltimateTrackingUrl: {
      default: '',
    },
    monthlyCommitmentPurchased: {
      default: 0,
    },
    trialActive: {
      default: false,
    },
    eligibleForTrial: {
      default: false,
    },
    startTrialPath: {
      default: '',
    },
  },
  seeAllFeaturesLink: `${PROMO_URL}/pricing/ultimate`,
  handRaiseLeadButtonAttributes: {
    class: 'gl-w-full',
    'data-testid': 'ultimate-plan-talk-to-sales-button',
  },
  handRaiseLeadCtaTracking: {
    action: 'click_button',
    property: 'free_with_dap_monthly_commit',
  },
  computed: {
    hasDapMonthlyCommitment() {
      return this.monthlyCommitmentPurchased > 0;
    },
    showStartTrial() {
      return this.eligibleForTrial && !this.trialActive;
    },
  },
  methods: {
    triggerTrackCartAbandonment() {
      axios.post(this.upgradeToUltimateTrackingUrl).catch(() => {});
    },
  },
  ULTIMATE_PLAN_PRICE: '99',
};
</script>

<template>
  <div class="gl-flex gl-flex-1 gl-flex-col">
    <gl-card
      class="gl-border gl-rounded-b-none gl-bg-subtle gl-p-5"
      body-class="gl-bg-transparent gl-text-subtle"
      header-class="gl-pb-0 gl-mb-0 gl-heading-scale-600"
    >
      <template #header>
        {{ s__('BillingPlans|Ultimate') }}
      </template>

      <template #default>
        <p>
          {{
            s__(
              'BillingPlans|Start a free trial of Ultimate with advanced enterprise security, no credit card required.',
            )
          }}
        </p>
        <p class="gl-mb-0 gl-mt-5 gl-flex">
          <span class="gl-mr-1 gl-mt-1 gl-text-lg gl-font-bold gl-text-default">$</span>
          <span class="gl-heading-scale-600">
            {{ $options.ULTIMATE_PLAN_PRICE }}
          </span>
          <span class="gl-ml-3 gl-self-center gl-text-sm">
            {{ s__('BillingPlans|per user/month, billed annually') }}
          </span>
        </p>
      </template>

      <template #footer>
        <div class="gl-flex gl-flex-col gl-gap-5 md:gl-flex-row">
          <div v-if="!hasDapMonthlyCommitment" class="gl-flex-1">
            <gl-button
              block
              data-event-tracking="click_upgrade_to_ultimate_on_billing_page"
              :href="upgradeToUltimateUrl"
              referrerpolicy="no-referrer-when-downgrade"
              @click="triggerTrackCartAbandonment"
              >{{ s__('BillingPlans|Upgrade to Ultimate') }}
            </gl-button>
          </div>
          <div v-if="showStartTrial" class="gl-flex-1">
            <gl-button block :href="startTrialPath" referrerpolicy="no-referrer-when-downgrade"
              >{{ s__('BillingPlans|Try for free') }}
            </gl-button>
          </div>
          <div v-if="hasDapMonthlyCommitment" class="gl-flex-1">
            <hand-raise-lead-button
              glm-content="billing-group"
              :button-text="s__('BillingPlans|Talk to sales')"
              :button-attributes="$options.handRaiseLeadButtonAttributes"
              :cta-tracking="$options.handRaiseLeadCtaTracking"
            />
          </div>
        </div>
      </template>
    </gl-card>

    <div class="gl-border gl-rounded-b-xl gl-border-t-0 gl-p-6">
      <h3 class="gl-mt-0 gl-text-lg">
        {{ s__('BillingPlans|Everything from Premium, plus:') }}
      </h3>

      <ul
        class="gl-mt-5 gl-flex gl-list-none gl-flex-col gl-gap-5 gl-pl-0 gl-text-lg gl-text-subtle"
      >
        <li>
          <gl-icon name="check" variant="info" class="gl-mr-2" />
          <span>{{ s__('BillingPlans|Application Security Testing') }}</span>
        </li>

        <li>
          <gl-icon name="check" variant="info" class="gl-mr-2" />
          <span>{{ s__('BillingPlans|Software Supply Chain Security') }}</span>
        </li>

        <li>
          <gl-icon name="check" variant="info" class="gl-mr-2" />
          <span>{{ s__('BillingPlans|Vulnerability Management') }}</span>
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
