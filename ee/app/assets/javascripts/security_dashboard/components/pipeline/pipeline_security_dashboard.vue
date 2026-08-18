<script>
import { GlLink, GlSprintf } from '@gitlab/ui';
import pipelineSecurityReportSummaryQuery from 'ee/security_dashboard/graphql/queries/pipeline_security_report_summary.query.graphql';
import { reportTypeToSecurityReportTypeEnum } from 'ee/vue_shared/security_reports/constants';
import { fetchPolicies } from '~/lib/graphql';
import { s__ } from '~/locale';
import { helpPagePath } from '~/helpers/help_page_helper';
import SbomReportsErrorsAlert from 'ee/dependencies/components/sbom_reports_errors_alert.vue';
import ScanAlerts, { TYPE_ERRORS, TYPE_WARNINGS } from './scan_alerts.vue';
import ReportStatusAlert, { STATUS_PURGED } from './report_status_alert.vue';
import SecurityReportsSummary from './security_reports_summary.vue';
import PipelineVulnerabilityReport from './pipeline_vulnerability_report.vue';

export default {
  name: 'PipelineSecurityDashboard',
  errorsAlertType: TYPE_ERRORS,
  warningsAlertType: TYPE_WARNINGS,
  scanPurgedStatus: STATUS_PURGED,
  components: {
    ReportStatusAlert,
    ScanAlerts,
    SecurityReportsSummary,
    PipelineVulnerabilityReport,
    GlSprintf,
    GlLink,
    SbomReportsErrorsAlert,
  },
  provide() {
    return {
      dismissalDescriptions: this.dismissalDescriptions,
      validityChecksEnabled: this.validityChecksEnabled,
    };
  },
  inject: ['pipeline', 'projectFullPath'],
  props: {
    dismissalDescriptions: {
      type: Object,
      required: false,
      default: () => ({}),
    },
    sbomReportsErrors: {
      type: Array,
      required: true,
    },
    validityChecksEnabled: {
      type: Boolean,
      required: false,
    },
  },
  data() {
    return {
      securityReportSummary: {},
    };
  },
  apollo: {
    securityReportSummary: {
      query: pipelineSecurityReportSummaryQuery,
      fetchPolicy: fetchPolicies.NETWORK_ONLY,
      variables() {
        return {
          fullPath: this.projectFullPath,
          pipelineIid: this.pipeline.iid,
          reportTypes: Object.values(reportTypeToSecurityReportTypeEnum),
        };
      },
      update(data) {
        const summary = {
          reports: data?.project?.pipeline?.securityReportSummary,
          jobs: data?.project?.pipeline?.jobs?.nodes,
        };
        return summary?.reports && Object.keys(summary.reports).length ? summary : null;
      },
    },
  },
  computed: {
    reportSummary() {
      return this.securityReportSummary?.reports;
    },
    jobs() {
      return this.securityReportSummary?.jobs;
    },
    scans() {
      const getScans = (reportSummary) => reportSummary?.scans?.nodes || [];

      return this.reportSummary
        ? Object.values(this.reportSummary)
            // generate flat array of all scans
            .flatMap(getScans)
        : [];
    },
    hasScans() {
      return this.scans.length > 0;
    },
    purgedScans() {
      return this.scans.filter((scan) => scan.status === this.$options.scanPurgedStatus);
    },
    hasPurgedScans() {
      return this.purgedScans.length > 0;
    },
    scansWithErrors() {
      const hasErrors = (scan) => Boolean(scan.errors?.length);

      return this.scans.filter(hasErrors);
    },
    showScanErrors() {
      return this.scansWithErrors.length > 0 && !this.hasPurgedScans;
    },
    scansWithWarnings() {
      const hasWarnings = (scan) => Boolean(scan.warnings?.length);

      return this.scans.filter(hasWarnings);
    },
    showScanWarnings() {
      return this.scansWithWarnings.length > 0 && !this.hasPurgedScans;
    },
    showSbomErrors() {
      return this.sbomReportsErrors.length > 0;
    },
  },
  i18n: {
    parsingErrorAlertTitle: s__('SecurityReports|Error parsing security reports'),
    parsingErrorAlertDescription: s__(
      'SecurityReports|The following security reports contain one or more vulnerability findings that could not be parsed and were not recorded. To investigate a report, download the artifacts in the job output. Ensure the security report conforms to the relevant %{helpPageLinkStart}JSON schema%{helpPageLinkEnd}.',
    ),
    parsingWarningAlertTitle: s__('SecurityReports|Warning parsing security reports'),
    parsingWarningAlertDescription: s__(
      'SecurityReports|Check the messages generated while parsing the following security reports, as they may prevent the results from being ingested by GitLab. Ensure the security report conforms to a supported %{helpPageLinkStart}JSON schema%{helpPageLinkEnd}.',
    ),
    sbomReportsErrorsDescription: s__(
      'SecurityReports|The following SBOM reports could not be parsed. Therefore the list of reported vulnerabilities may be incomplete.',
    ),
    pageDescription: s__(
      'SecurityReports|Results show vulnerability findings from the latest successful %{helpPageLinkStart}pipeline%{helpPageLinkEnd}.',
    ),
    pageDescriptionHelpLink: helpPagePath(
      'user/application_security/detect/security_scanning_results',
    ),
  },
};
</script>

<template>
  <div class="gl-mt-5">
    <p data-testid="page-description">
      <gl-sprintf :message="$options.i18n.pageDescription">
        <template #helpPageLink="{ content }">
          <gl-link :href="$options.i18n.pageDescriptionHelpLink" target="_blank">{{
            content
          }}</gl-link>
        </template>
      </gl-sprintf>
    </p>

    <sbom-reports-errors-alert
      v-if="showSbomErrors"
      :errors="sbomReportsErrors"
      :error-description="$options.i18n.sbomReportsErrorsDescription"
      class="gl-mb-5"
    />

    <div v-if="hasScans" class="gl-mb-5">
      <scan-alerts
        v-if="showScanErrors"
        :type="$options.errorsAlertType"
        :scans="scansWithErrors"
        :title="$options.i18n.parsingErrorAlertTitle"
        :description="$options.i18n.parsingErrorAlertDescription"
        class="gl-mb-5"
      />
      <scan-alerts
        v-if="showScanWarnings"
        :type="$options.warningsAlertType"
        :scans="scansWithWarnings"
        :title="$options.i18n.parsingWarningAlertTitle"
        :description="$options.i18n.parsingWarningAlertDescription"
        class="gl-mb-5"
      />

      <report-status-alert v-if="hasPurgedScans" class="gl-mb-5" />
      <security-reports-summary :summary="reportSummary" :jobs="jobs" />
    </div>

    <pipeline-vulnerability-report data-testid="pipeline-vulnerability-report" />
  </div>
</template>
