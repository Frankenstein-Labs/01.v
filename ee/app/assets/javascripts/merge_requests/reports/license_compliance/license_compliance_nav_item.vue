<script>
import { LICENSE_COMPLIANCE_ROUTE } from '~/merge_requests/reports/constants';
import ReportListItem from '~/merge_requests/reports/components/report_list_item.vue';

export default {
  name: 'LicenseComplianceNavItem',
  components: {
    ReportListItem,
  },
  inject: ['isLicenseComplianceLoading', 'statusIconName'],
  routeNames: {
    LICENSE_COMPLIANCE_ROUTE,
  },
};
</script>

<template>
  <report-list-item
    :to="$options.routeNames.LICENSE_COMPLIANCE_ROUTE"
    :status-icon="statusIconName"
    :is-loading="isLicenseComplianceLoading"
  >
    {{ s__('MrReports|License compliance') }}
  </report-list-item>
</template>
