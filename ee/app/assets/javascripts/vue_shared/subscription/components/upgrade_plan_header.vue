<script>
import { GlIcon, GlButton, GlLink, GlPopover } from '@gitlab/ui';
import { s__, sprintf } from '~/locale';
import { InternalEvents } from '~/tracking';
import { focusDuoChatInput } from 'ee/ai/utils';
import { PROMO_URL } from '~/constants';
import {
  DUO_CHAT_FEATURE_ID,
  FEATURE_HIGHLIGHTS,
  getTrialActiveFeatureHighlights,
} from './constants';

const trackingMixin = InternalEvents.mixin();

export default {
  name: 'UpgradePlanHeader',
  DUO_CHAT_FEATURE_ID,
  components: {
    GlIcon,
    GlButton,
    GlPopover,
    GlLink,
  },
  mixins: [trackingMixin],
  props: {
    isSaas: {
      type: Boolean,
      required: true,
    },
    trialActive: {
      type: Boolean,
      required: true,
    },
    trialExpired: {
      type: Boolean,
      required: true,
    },
    startTrialPath: {
      type: String,
      required: true,
    },
    upgradeToPremiumUrl: {
      type: String,
      required: false,
      default: '',
    },
    canAccessDuoChat: {
      type: Boolean,
      required: true,
    },
    exploreLinks: {
      type: Object,
      required: false,
      default: () => {},
    },
  },
  computed: {
    attributes() {
      if (!this.isSaas) {
        return {
          ...FEATURE_HIGHLIGHTS.notInTrialSM,
          ctaHref: this.startTrialPath,
          ctaTrackingData: {
            'data-event-tracking': 'click_sm_ultimate_trial_subscription_page',
          },
          ctaSecondaryHref: `${PROMO_URL}/pricing/?deployment=self-managed-deployment`,
          ctaTrackingSecondaryData: {
            'data-event-tracking': 'click_sm_explore_plans_subscription_page',
          },
        };
      }

      if (this.trialActive) {
        return {
          ...getTrialActiveFeatureHighlights(),
          postScript: s__(
            'BillingPlans|Upgrade before your trial ends to maintain access to these Premium features.',
          ),
          ctaHref: this.upgradeToPremiumUrl,
          ctaTrackingData: {
            'data-track-action': 'click_button',
            'data-track-label': 'plan_cta',
            'data-track-property': 'premium',
          },
        };
      }

      if (this.trialExpired) {
        return {
          ...FEATURE_HIGHLIGHTS.trialExpired,
          ctaHref: this.upgradeToPremiumUrl,
          ctaTrackingData: {
            'data-track-action': 'click_button',
            'data-track-label': 'plan_cta',
            'data-track-property': 'premium',
          },
        };
      }

      return {
        ...FEATURE_HIGHLIGHTS.notInTrialSaas,
        ctaHref: this.startTrialPath,
        ctaTrackingData: {
          'data-event-tracking': 'click_duo_enterprise_trial_billing_page',
          'data-event-label': 'ultimate_and_duo_enterprise_trial',
        },
      };
    },
  },
  methods: {
    handleExploreLinkClick(id) {
      if (id === this.$options.DUO_CHAT_FEATURE_ID && this.canAccessDuoChat) {
        focusDuoChatInput();
      }

      this.trackEvent('click_cta_premium_feature_popover_on_billings', {
        property: id,
      });
    },
    handlePopoverHover(id) {
      this.trackEvent('render_premium_feature_popover_on_billings', {
        property: id,
      });
    },
    featureButtonText(feature) {
      return (
        feature.buttonText ||
        sprintf(s__('BillingPlans|Explore %{feature}'), { feature: feature.title })
      );
    },
  },
};
</script>

<template>
  <div
    class="gl-border gl-flex-1 gl-rounded-b-lg gl-border-t-0 gl-bg-subtle gl-p-6 md:gl-border-t md:gl-rounded-l-none md:gl-rounded-r-lg md:gl-border-l-0"
  >
    <div>
      <h3 class="gl-heading-3-fixed gl-mb-3 gl-text-default">
        {{ attributes.header }}
      </h3>

      <div class="gl-text-sm gl-text-subtle">
        {{ attributes.subheader }}
      </div>

      <div
        :class="{
          'gl-mb-3 gl-mt-3 gl-grid gl-grid-flow-col gl-grid-cols-2 gl-grid-rows-3': trialActive,
        }"
      >
        <div v-for="feature in attributes.features" :key="feature.id" class="gl-mb-3 gl-mt-3">
          <div :id="feature.id">
            <gl-icon :name="feature.iconName" class="gl-mr-2 gl-mt-1" :variant="feature.variant" />
            <gl-link
              v-if="feature.showAsLink && feature.docsLink"
              data-testid="feature-link"
              class="gl-text-sm"
              :href="feature.docsLink"
              target="_blank"
              v-bind="feature.tracking"
            >
              {{ feature.title }}
            </gl-link>
            <span v-else :class="trialActive ? 'gl-text-base gl-underline' : 'gl-text-sm'">{{
              feature.title
            }}</span>
          </div>
          <gl-popover
            v-if="trialActive"
            :target="feature.id"
            :title="feature.title"
            show-close-button
            @shown="handlePopoverHover(feature.id)"
          >
            {{ feature.description }}

            <gl-link :href="feature.docsLink" target="_blank">
              {{ s__('BillingPlans|Learn more.') }}
            </gl-link>

            <gl-button
              v-if="exploreLinks[feature.id] || feature.id === $options.DUO_CHAT_FEATURE_ID"
              class="gl-mt-3 gl-w-full"
              :href="feature.buttonText ? feature.docsLink : exploreLinks[feature.id]"
              variant="confirm"
              @click="handleExploreLinkClick(feature.id)"
            >
              {{ featureButtonText(feature) }}
            </gl-button>
          </gl-popover>
        </div>
      </div>

      <div v-if="attributes.postScript" class="gl-text-sm gl-text-subtle">
        {{ attributes.postScript }}
      </div>
    </div>

    <div class="gl-mt-5 gl-flex gl-gap-3">
      <gl-button
        data-testid="upgrade-link-cta"
        :class="{ 'gl-w-full': trialActive }"
        :category="trialActive || attributes.secondaryCtaLabel ? 'primary' : 'secondary'"
        :variant="trialActive || attributes.secondaryCtaLabel ? 'confirm' : 'default'"
        v-bind="attributes.ctaTrackingData"
        :href="attributes.ctaHref"
        referrerpolicy="no-referrer-when-downgrade"
        :target="isSaas && '_blank'"
      >
        {{ attributes.ctaLabel }}
      </gl-button>
      <gl-button
        v-if="Boolean(attributes.secondaryCtaLabel)"
        data-testid="explore-link-cta"
        category="secondary"
        variant="confirm"
        v-bind="attributes.ctaTrackingSecondaryData"
        :href="attributes.ctaSecondaryHref"
        referrerpolicy="no-referrer-when-downgrade"
        target="_blank"
      >
        {{ attributes.secondaryCtaLabel }}
      </gl-button>
    </div>
  </div>
</template>
