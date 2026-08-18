<script>
import { GlButton, GlTooltipDirective as GlTooltip } from '@gitlab/ui';
import HelpIcon from '~/vue_shared/components/help_icon/help_icon.vue';
import {
  PRE_SCAN_VERIFICATION_STATUS,
  PRE_SCAN_VERIFICATION_STEPS,
  PRE_SCAN_VERIFICATION_LIST_TRANSLATIONS,
  PRE_SCAN_VERIFICATION_STEPS_LAST_INDEX,
} from '../constants';
import PreScanVerificationStep from './pre_scan_verification_step.vue';

export default {
  PRE_SCAN_VERIFICATION_STEPS,
  PRE_SCAN_VERIFICATION_STEPS_LAST_INDEX,
  i18n: PRE_SCAN_VERIFICATION_LIST_TRANSLATIONS,
  name: 'PreScanVerificationList',
  directives: {
    GlTooltip,
  },
  components: {
    GlButton,
    HelpIcon,
    PreScanVerificationStep,
  },
  props: {
    status: {
      type: String,
      required: false,
      default: PRE_SCAN_VERIFICATION_STATUS.DEFAULT,
    },
  },
  computed: {
    buttonText() {
      return this.status === PRE_SCAN_VERIFICATION_STATUS.IN_PROGRESS
        ? this.$options.i18n.preScanVerificationButtonInProgress
        : this.$options.i18n.preScanVerificationButtonDefault;
    },
    buttonVariant() {
      return this.isVerificationInProgress ? 'danger' : 'confirm';
    },
    buttonCategory() {
      return this.isVerificationInProgress ? 'secondary' : 'primary';
    },
    buttonDisabled() {
      /**
       * TODO Implement when backend is finished
       */
      return false;
    },
    buttonTooltip() {
      return this.buttonDisabled ? this.$options.i18n.preScanVerificationButtonTooltip : '';
    },
    isVerificationInProgress() {
      return this.status === PRE_SCAN_VERIFICATION_STATUS.IN_PROGRESS;
    },
  },
};
</script>

<template>
  <div>
    <div class="gl-mb-4 gl-flex gl-items-center">
      <h4 class="gl-my-0 gl-text-lg">
        {{ $options.i18n.preScanVerificationListHeader }}
      </h4>
      <help-icon
        v-gl-tooltip
        class="gl-ml-3"
        :title="$options.i18n.preScanVerificationListTooltip"
      />
    </div>
    <pre-scan-verification-step
      v-for="(step, index) in $options.PRE_SCAN_VERIFICATION_STEPS"
      :key="step.header"
      :step="step"
      :status="status"
      :show-divider="index !== $options.PRE_SCAN_VERIFICATION_STEPS_LAST_INDEX"
    />
    <gl-button
      v-gl-tooltip
      class="gl-mt-6"
      data-testid="pre-scan-verification-submit"
      :category="buttonCategory"
      :variant="buttonVariant"
      :title="buttonTooltip"
      :disabled="buttonDisabled"
    >
      {{ buttonText }}
    </gl-button>
  </div>
</template>
