<script>
import { s__ } from '~/locale';
import { helpPagePath } from '~/helpers/help_page_helper';
import ReportSection from '~/merge_requests/reports/components/report_section.vue';
import { getSummaryTextWithReportItems } from 'ee/vue_merge_request_widget/widgets/license_compliance/utils';

export default {
  name: 'LicenseComplianceContent',
  components: {
    ReportSection,
  },
  inject: [
    'newLicensesCount',
    'existingLicensesCount',
    'hasDeniedLicense',
    'hasApprovalRequired',
    'isLicenseComplianceLoading',
    'statusIconName',
    'statusMessage',
    'errorMessage',
    'sections',
    'loadingMessage',
  ],
  props: {
    mr: {
      type: Object,
      required: true,
    },
  },
  computed: {
    hasBaseReportLicenses() {
      return this.existingLicensesCount > 0;
    },
    summaryText() {
      if (this.statusMessage) {
        return this.statusMessage;
      }
      if (this.errorMessage) {
        return this.errorMessage;
      }
      if (this.newLicensesCount > 0) {
        return getSummaryTextWithReportItems({
          hasBaseReportLicenses: this.hasBaseReportLicenses,
          hasDeniedLicense: this.hasDeniedLicense,
          hasApprovalRequired: this.hasApprovalRequired,
          licenseReportCount: this.newLicensesCount,
        });
      }

      if (this.hasBaseReportLicenses) {
        return s__('LicenseCompliance|License compliance detected no new licenses');
      }
      return s__(
        'LicenseCompliance|License compliance detected no licenses for the source branch only',
      );
    },
    summary() {
      return { title: this.summaryText };
    },
    fullReportPath() {
      return this.mr.licenseCompliance && this.mr.licenseCompliance.license_scanning
        ? this.mr.licenseCompliance.license_scanning.full_report_path
        : undefined;
    },
    hasLicenseScanResults() {
      return !this.statusMessage && this.fullReportPath;
    },
    helpPopover() {
      if (!this.hasLicenseScanResults) {
        return null;
      }
      return {
        options: { title: s__('ciReport|License scan results') },
        content: {
          text: s__('ciReport|Detects known vulnerabilities in your software dependencies.'),
          learnMorePath: helpPagePath('user/compliance/license_approval_policies', {
            anchor:
              'criteria-to-compare-licenses-detected-in-the-merge-request-branch-to-licenses-in-the-default-branch',
          }),
        },
      };
    },
    actionButtons() {
      if (!this.hasLicenseScanResults) {
        return [];
      }
      return [
        {
          text: s__('ciReport|Full report'),
          href: this.fullReportPath,
          target: '_self',
        },
      ];
    },
  },
};
</script>

<template>
  <report-section
    :is-loading="isLicenseComplianceLoading"
    :loading-text="loadingMessage"
    :summary="summary"
    :status-icon-name="statusIconName"
    :help-popover="helpPopover"
    :action-buttons="actionButtons"
    :sections="sections"
  />
</template>
