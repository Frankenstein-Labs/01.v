<script>
import { GlDrawer } from '@gitlab/ui';
import { s__ } from '~/locale';
import { getContentWrapperHeight } from '~/lib/utils/dom_utils';
import { DRAWER_Z_INDEX } from '~/lib/utils/constants';
import { PRE_SCAN_VERIFICATION_STATUS } from '../constants';
import PreScanVerificationAlert from './pre_scan_verification_alert.vue';
import PreScanVerificationList from './pre_scan_verification_list.vue';
import PreScanVerificationSummary from './pre_scan_verification_summary.vue';

export default {
  i18n: {
    preScanVerificationSidebarHeader: s__('PreScanVerification|Pre-scan verification'),
    preScanVerificationSidebarInfo: s__(
      'PreScanVerification|Test your configuration and identify potential errors before running a full scan.',
    ),
  },
  name: 'PreScanVerificationSidebar',
  components: {
    GlDrawer,
    PreScanVerificationAlert,
    PreScanVerificationList,
    PreScanVerificationSummary,
  },
  props: {
    open: {
      type: Boolean,
      required: false,
      default: false,
    },
    status: {
      type: String,
      required: false,
      default: PRE_SCAN_VERIFICATION_STATUS.DEFAULT,
    },
    showAlert: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  emits: ['close', 'dismiss-alert'],
  computed: {
    isDefaultStatus() {
      return this.status === PRE_SCAN_VERIFICATION_STATUS.DEFAULT;
    },
    getDrawerHeaderHeight() {
      return getContentWrapperHeight();
    },
  },
  DRAWER_Z_INDEX,
};
</script>

<template>
  <gl-drawer
    :header-height="getDrawerHeaderHeight"
    :header-sticky="true"
    :open="open"
    :z-index="$options.DRAWER_Z_INDEX"
    @close="$emit('close')"
  >
    <template #title>
      <h4 data-testid="sidebar-header" class="gl-my-0 gl-text-size-h2">
        {{ $options.i18n.preScanVerificationSidebarHeader }}
      </h4>
    </template>
    <template #default>
      <pre-scan-verification-alert
        v-if="showAlert"
        pipeline-created-at="2022-09-23 11:19:49 UTC"
        :status="status"
        class="gl-mx-6 gl-mt-5 gl-border-0 !gl-px-9 !gl-py-5"
        @dismiss="$emit('dismiss-alert')"
      />

      <p class="gl-mb-0 gl-border-0 gl-leading-20 gl-text-subtle">
        {{ $options.i18n.preScanVerificationSidebarInfo }}
      </p>

      <pre-scan-verification-summary v-if="!isDefaultStatus" :status="status" />

      <pre-scan-verification-list class="!gl-pt-0" :status="status" />
    </template>
  </gl-drawer>
</template>
