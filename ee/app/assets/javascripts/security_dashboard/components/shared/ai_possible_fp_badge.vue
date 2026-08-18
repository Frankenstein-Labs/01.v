<script>
import { GlBadge, GlIcon, GlPopover, GlProgressBar } from '@gitlab/ui';
import { CONFIDENCE_SCORES } from 'ee/vulnerabilities/constants';
import { isPendingFpDetection, isFailedFpDetection } from 'ee/vulnerabilities/flag_helpers';
import { s__ } from '~/locale';

export default {
  components: {
    GlBadge,
    GlIcon,
    GlPopover,
    GlProgressBar,
  },
  props: {
    vulnerability: {
      type: Object,
      required: true,
    },
  },
  computed: {
    flag() {
      return this.vulnerability.latestFlag;
    },
    isLikelyFalsePositive() {
      return this.flag.confidenceScore >= CONFIDENCE_SCORES.LIKELY_FALSE_POSITIVE;
    },
    isAboveMinimalConfidence() {
      return this.flag?.confidenceScore > CONFIDENCE_SCORES.MINIMAL;
    },
    isPending() {
      return isPendingFpDetection(this.flag);
    },
    isFailed() {
      return isFailedFpDetection(this.flag);
    },
    badgeText() {
      if (this.isPending) {
        return this.$options.i18n.badgeTextScanning;
      }
      if (this.isFailed) {
        return this.$options.i18n.badgeTextScanFailed;
      }
      if (this.isLikelyFalsePositive) {
        return this.$options.i18n.badgeTextLikelyFP;
      }
      if (this.isAboveMinimalConfidence) {
        return this.$options.i18n.badgeTextPossibleFP;
      }
      return this.$options.i18n.badgeTextNotFP;
    },
    badgeVariant() {
      if (this.isPending) {
        return 'info';
      }
      if (this.isFailed) {
        return 'danger';
      }
      if (this.isLikelyFalsePositive) {
        return 'success';
      }
      if (this.isAboveMinimalConfidence) {
        return 'warning';
      }
      return 'neutral';
    },
    progressBarVariant() {
      return this.badgeVariant === 'neutral' ? 'primary' : this.badgeVariant;
    },
    popoverTitle() {
      if (this.isPending) {
        return this.$options.i18n.popoverTitleScanning;
      }
      if (this.isFailed) {
        return this.$options.i18n.popoverTitleFailed;
      }
      if (this.isLikelyFalsePositive || this.isAboveMinimalConfidence) {
        return this.$options.i18n.popoverTitleFP;
      }
      return this.$options.i18n.popoverTitleNotFP;
    },
    showConfidenceDetails() {
      return !this.isPending && !this.isFailed;
    },
    confidencePercentage() {
      return Math.round(this.flag.confidenceScore * 100);
    },
  },
  i18n: {
    badgeTextPossibleFP: s__('Vulnerability|Possible FP'),
    badgeTextLikelyFP: s__('Vulnerability|Likely FP'),
    badgeTextNotFP: s__('Vulnerability|Not an FP'),
    popoverTitleFP: s__('Vulnerability|AI false positive confidence score'),
    popoverTitleNotFP: s__('Vulnerability|AI false positive scan complete'),
    badgeTextScanning: s__('Vulnerability|FP scanning'),
    badgeTextScanFailed: s__('Vulnerability|FP scan failed'),
    popoverTitleScanning: s__('Vulnerability|AI false positive scan in progress'),
    popoverTitleFailed: s__('Vulnerability|AI false positive scan failed'),
  },
};
</script>

<template>
  <gl-badge ref="badge" :variant="badgeVariant" size="sm">
    <gl-icon name="tanuki-ai" class="gl-mr-1" />
    <span data-testid="ai-fix-in-progress-b"> {{ badgeText }}</span>
    <gl-popover
      :target="() => $refs.badge"
      placement="left"
      show-close-button
      :css-classes="['gl-max-w-62']"
    >
      <template #title>{{ popoverTitle }}</template>
      <template v-if="showConfidenceDetails">
        <div class="gl-mt-2 gl-flex gl-items-center gl-gap-3 gl-font-bold">
          <gl-progress-bar
            :value="confidencePercentage"
            class="gl-h-3 gl-w-26"
            :variant="progressBarVariant"
          />
          {{ confidencePercentage }}%
        </div>
        <div class="gl-mt-3 gl-w-26">
          <template v-if="isAboveMinimalConfidence">
            {{ s__('Vulnerability|For more information, view vulnerability details.') }}
          </template>
          <template v-else>
            {{ s__('Vulnerability|FP scanning found that this vulnerability is ')
            }}<strong>{{ s__('Vulnerability|NOT a false positive') }}</strong>
          </template>
        </div>
      </template>
    </gl-popover>
  </gl-badge>
</template>
