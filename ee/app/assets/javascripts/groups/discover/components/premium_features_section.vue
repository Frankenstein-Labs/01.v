<script>
import DapBuyCreditsCard from './dap_buy_credits_card.vue';
import FeatureCard from './feature_card.vue';
import {
  PREMIUM_FEATURES_CICD,
  PREMIUM_FEATURES_PLATFORM,
  PREMIUM_FEATURES_VISIBILITY,
  PREMIUM_FEATURES_SCALE,
  DUO_FEATURES_COMPANION,
  DUO_AGENTIC_PLATFORM_LINK,
} from './constants';

export default {
  name: 'PremiumFeaturesSection',
  components: { DapBuyCreditsCard, FeatureCard },
  premiumFeaturesCicd: PREMIUM_FEATURES_CICD,
  premiumFeaturesPlatform: PREMIUM_FEATURES_PLATFORM,
  premiumFeaturesVisibility: PREMIUM_FEATURES_VISIBILITY,
  premiumFeaturesScale: PREMIUM_FEATURES_SCALE,
  duoFeaturesCompanion: DUO_FEATURES_COMPANION,
  duoAgenticPlatformLink: DUO_AGENTIC_PLATFORM_LINK,
  data() {
    return {
      openPopoverId: null,
    };
  },
  methods: {
    handlePopoverToggle(featureId) {
      // If clicking the same popover, close it; otherwise open the new one
      this.openPopoverId = this.openPopoverId === featureId ? null : featureId;
    },
  },
};
</script>

<template>
  <div class="gl-banner gl-rounded-2xl gl-p-8">
    <h2 class="gl-heading-2 gl-mb-3">
      {{ s__('BillingPlans|GitLab Premium') }}
    </h2>

    <p class="gl-mb-6 gl-text-lg gl-font-normal gl-text-default">
      {{ s__('BillingPlans|Everything from Free, plus:') }}
    </p>
    <div class="gl-mb-8 gl-grid gl-grid-cols-1 gl-gap-6 md:gl-grid-cols-2">
      <feature-card
        :top-header="s__('BillingPlans|Enhanced CI/CD')"
        :bottom-header="s__('BillingPlans|Strengthen pipelines with advanced approvals workflows')"
        :items="$options.premiumFeaturesCicd"
        :open-popover-id="openPopoverId"
        :handle-popover-toggle="handlePopoverToggle"
        data-testid="premium-features-cicd"
      />

      <feature-card
        :top-header="s__('BillingPlans|Unified Platform')"
        :bottom-header="s__('BillingPlans|Consolidate your toolchain in one place')"
        :items="$options.premiumFeaturesPlatform"
        :open-popover-id="openPopoverId"
        :handle-popover-toggle="handlePopoverToggle"
        data-testid="premium-features-platform"
      />
      <feature-card
        :top-header="s__('BillingPlans|Visibility & Incident Response')"
        :bottom-header="s__('BillingPlans|Track critical actions and respond when issues arise')"
        :items="$options.premiumFeaturesVisibility"
        :open-popover-id="openPopoverId"
        :handle-popover-toggle="handlePopoverToggle"
        data-testid="premium-features-visibility"
      />
      <feature-card
        :top-header="s__('BillingPlans|Scale with Confidence')"
        :bottom-header="s__('BillingPlans|Built to grow with your team')"
        :items="$options.premiumFeaturesScale"
        :open-popover-id="openPopoverId"
        :handle-popover-toggle="handlePopoverToggle"
        data-testid="premium-features-scale"
      />
    </div>
    <h2 class="gl-heading-2 gl-mb-3">
      {{ s__('BillingPlans|GitLab Duo Agent Platform') }}
    </h2>
    <p class="gl-mb-6 gl-text-lg gl-font-normal gl-text-default">
      {{ s__('BillingPlans|AI across the software development lifecycle.') }}
      <a
        :href="$options.duoAgenticPlatformLink"
        class="gl-link-inline gl-text-default"
        target="_blank"
        rel="noopener noreferrer"
        >{{ __('Learn more') }}</a
      >.
    </p>
    <div class="gl-grid gl-grid-cols-1 gl-gap-6 md:gl-grid-cols-2">
      <feature-card
        :top-header="s__('BillingPlans|Your AI companion throughout development')"
        :bottom-header="s__('BillingPlans|Access AI assistance wherever you\'re most productive')"
        :items="$options.duoFeaturesCompanion"
        :open-popover-id="openPopoverId"
        :handle-popover-toggle="handlePopoverToggle"
        data-testid="duo-features-companion"
      />
      <dap-buy-credits-card data-testid="dap-buy-credits-card" />
    </div>
  </div>
</template>
