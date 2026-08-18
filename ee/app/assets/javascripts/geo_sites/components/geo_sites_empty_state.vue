<script>
import { GlEmptyState, GlBadge } from '@gitlab/ui';
import { s__, __ } from '~/locale';
import { GEO_INFO_URL, GITLAB_PRICING_URL } from '../constants';

export default {
  name: 'GeoSitesEmptyState',
  i18n: {
    learnMoreButtonText: __('Learn more'),
    manageSubscriptionButtonText: s__('Geo|Manage your subscription'),
    premiumBadgeText: __('Premium'),
    availableOnPremiumOnly: __('Available only on GitLab Premium.'),
  },
  components: {
    GlEmptyState,
    GlBadge,
  },
  inject: {
    geoSitesEmptyStateSvg: {
      default: '',
    },
    geoLicenseAllows: {
      default: true,
    },
    manageSubscriptionUrl: {
      default: '',
    },
  },
  props: {
    title: {
      type: String,
      required: true,
    },
    description: {
      type: String,
      required: false,
      default: '',
    },
    showLearnMoreButton: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  computed: {
    showLicenseUpgradeCta() {
      return this.showLearnMoreButton && !this.geoLicenseAllows;
    },
    primaryButtonLink() {
      if (!this.showLearnMoreButton) {
        return '';
      }
      return this.showLicenseUpgradeCta ? this.manageSubscriptionUrl : GEO_INFO_URL;
    },
    primaryButtonText() {
      if (!this.showLearnMoreButton) {
        return '';
      }
      return this.showLicenseUpgradeCta
        ? this.$options.i18n.manageSubscriptionButtonText
        : this.$options.i18n.learnMoreButtonText;
    },
    secondaryButtonLink() {
      return this.showLicenseUpgradeCta ? GEO_INFO_URL : '';
    },
    secondaryButtonText() {
      return this.showLicenseUpgradeCta ? this.$options.i18n.learnMoreButtonText : '';
    },
    displayDescription() {
      if (this.showLicenseUpgradeCta) {
        return `${this.description} ${this.$options.i18n.availableOnPremiumOnly}`;
      }
      return this.description;
    },
  },
  GITLAB_PRICING_URL,
};
</script>

<template>
  <gl-empty-state
    :svg-path="geoSitesEmptyStateSvg"
    :svg-height="null"
    :description="displayDescription"
    :primary-button-link="primaryButtonLink"
    :primary-button-text="primaryButtonText"
    :secondary-button-link="secondaryButtonLink"
    :secondary-button-text="secondaryButtonText"
  >
    <template #title>
      <h1 class="h4 gl-mb-0 gl-mt-0 gl-text-size-h-display gl-leading-36">
        {{ title }}
        <gl-badge
          v-if="showLicenseUpgradeCta"
          variant="tier"
          icon="license"
          :href="$options.GITLAB_PRICING_URL"
          target="_blank"
        >
          {{ $options.i18n.premiumBadgeText }}
        </gl-badge>
      </h1>
    </template>
  </gl-empty-state>
</template>
