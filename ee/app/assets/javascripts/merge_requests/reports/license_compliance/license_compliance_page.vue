<script>
import { InternalEvents } from '~/tracking';
import {
  LICENSE_COMPLIANCE_ROUTE,
  VIEW_MERGE_REQUEST_REPORT,
  TRACKING_LABEL_BY_ROUTE,
} from '~/merge_requests/reports/constants';
import LicenseComplianceProvider from './license_compliance_provider.vue';
import LicenseComplianceContent from './license_compliance_content.vue';

export default {
  name: 'LicenseCompliancePage',
  components: {
    LicenseComplianceProvider,
    LicenseComplianceContent,
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
      label: TRACKING_LABEL_BY_ROUTE[LICENSE_COMPLIANCE_ROUTE],
    });
  },
};
</script>

<template>
  <license-compliance-provider :mr="mr">
    <license-compliance-content :mr="mr" />
  </license-compliance-provider>
</template>
