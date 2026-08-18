<script>
import { GlAlert } from '@gitlab/ui';
import { glSlotsMixin } from '~/lib/utils/vue3compat/gl_slots_mixin';
import {
  PRE_SCAN_VERIFICATION_STATUS,
  ALERT_VARIANT_STATUS_MAP,
  PRE_SCAN_VERIFICATION_ALERT_TRANSLATIONS,
} from '../constants';
import PipelineDetails from './pipeline_details.vue';

export default {
  name: 'PreScanVerificationAlert',
  /**
   * TO DO Replace with dynamic content from backend
   */
  i18n: PRE_SCAN_VERIFICATION_ALERT_TRANSLATIONS,
  components: {
    GlAlert,
    PipelineDetails,
  },
  mixins: [glSlotsMixin],
  props: {
    status: {
      type: String,
      required: false,
      default: PRE_SCAN_VERIFICATION_STATUS.DEFAULT,
    },
    title: {
      type: String,
      required: false,
      default: '',
    },
    pipelineCreatedAt: {
      type: String,
      required: false,
      default: '',
    },
  },
  emits: ['dismiss'],
  computed: {
    alertVariant() {
      return ALERT_VARIANT_STATUS_MAP[this.status];
    },
    alertTitle() {
      return this.title || this.$options.i18n.preScanVerificationDefaultTitle;
    },
    showPipelineDetails() {
      return Boolean(this.pipelineCreatedAt);
    },
  },
};
</script>

<template>
  <gl-alert :variant="alertVariant" :title="alertTitle" @dismiss="$emit('dismiss')">
    <slot name="content">
      <span>{{ $options.i18n.preScanVerificationDefaultText }}</span>
      <span v-if="showPipelineDetails">
        <pipeline-details
          class="gl-inline gl-text-gray-50"
          :status="status"
          :pipeline-created-at="pipelineCreatedAt"
          pipeline-id="2343434"
          pipeline-path="test-path"
        />
      </span>
    </slot>
    <template v-if="glSlots().actions" #actions>
      <slot name="actions"></slot>
    </template>
  </gl-alert>
</template>
