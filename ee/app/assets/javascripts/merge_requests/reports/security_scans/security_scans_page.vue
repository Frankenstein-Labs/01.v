<script>
import { InternalEvents } from '~/tracking';
import {
  SECURITY_SCAN_ROUTE,
  VIEW_MERGE_REQUEST_REPORT,
  TRACKING_LABEL_BY_ROUTE,
} from '~/merge_requests/reports/constants';
import SecurityScansProvider from './security_scans_provider.vue';
import SecurityScansContent from './security_scans_content.vue';

export default {
  name: 'SecurityScansPage',
  components: {
    SecurityScansProvider,
    SecurityScansContent,
  },
  mixins: [InternalEvents.mixin()],
  props: {
    mr: {
      type: Object,
      required: true,
    },
  },
  mounted() {
    this.trackEvent(VIEW_MERGE_REQUEST_REPORT, {
      label: TRACKING_LABEL_BY_ROUTE[SECURITY_SCAN_ROUTE],
    });
  },
};
</script>

<template>
  <security-scans-provider :mr="mr">
    <security-scans-content :mr="mr" />
  </security-scans-provider>
</template>
