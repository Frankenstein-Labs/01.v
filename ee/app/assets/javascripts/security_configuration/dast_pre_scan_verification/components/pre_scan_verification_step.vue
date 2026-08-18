<script>
import { GlButton, GlTooltipDirective as GlTooltip } from '@gitlab/ui';
import { s__ } from '~/locale';
import { PRE_SCAN_VERIFICATION_STATUS } from '../constants';
import PreScanVerificationIcon from './pre_scan_verification_icon.vue';

export default {
  i18n: {
    downloadButtonText: s__('PreScanVerification|Download results'),
  },
  name: 'PreScanVerificationStep',
  directives: {
    GlTooltip,
  },
  components: {
    GlButton,
    PreScanVerificationIcon,
  },
  props: {
    step: {
      type: Object,
      required: true,
    },
    status: {
      type: String,
      required: false,
      default: PRE_SCAN_VERIFICATION_STATUS.DEFAULT,
    },
    showDivider: {
      type: Boolean,
      required: false,
      default: true,
    },
  },
  computed: {
    isFailedStatus() {
      return [
        PRE_SCAN_VERIFICATION_STATUS.FAILED,
        PRE_SCAN_VERIFICATION_STATUS.INVALIDATED,
      ].includes(this.status);
    },
    isVerificationFinished() {
      return ![
        PRE_SCAN_VERIFICATION_STATUS.DEFAULT,
        PRE_SCAN_VERIFICATION_STATUS.IN_PROGRESS,
      ].includes(this.status);
    },
    descriptionTextCssClass() {
      return this.isFailedStatus ? 'gl-text-danger' : 'gl-text-subtle';
    },
  },
};
</script>

<template>
  <div class="gl-flex gl-gap-5">
    <div class="gl-flex gl-flex-col gl-items-center">
      <pre-scan-verification-icon :status="status" />
      <div
        v-if="showDivider"
        data-testid="pre-scan-step-divider"
        class="gl-h-9 -gl-translate-x-1/2 gl-bg-gray-100"
        style="width: 1px"
      ></div>
    </div>
    <div class="gl-flex gl-items-start gl-gap-3 gl-pr-4">
      <div data-testid="pre-scan-step-content">
        <p class="gl-m-0 gl-mb-2 gl-font-bold gl-text-subtle">{{ step.header }}</p>
        <p
          data-testid="pre-scan-step-text"
          class="gl-m-0 gl-leading-normal"
          :class="descriptionTextCssClass"
        >
          {{ step.text }}
        </p>
      </div>
      <gl-button
        v-if="isVerificationFinished"
        v-gl-tooltip
        class="gl-border-0"
        category="tertiary"
        icon="download"
        :title="$options.i18n.downloadButtonText"
      />
    </div>
  </div>
</template>
