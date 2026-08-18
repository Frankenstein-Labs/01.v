<script>
import { defineAsyncComponent } from 'vue';
import CEWidgetApp from '~/vue_merge_request_widget/components/widget/app.vue';

// eslint-disable-next-line @gitlab/no-runtime-template-compiler -- We are reusing render from CE component
export default {
  name: 'WidgetApp',
  components: {
    MrBrowserPerformanceWidget: defineAsyncComponent(
      () => import('ee/vue_merge_request_widget/widgets/browser_performance/index.vue'),
    ),
    MrLoadPerformanceWidget: defineAsyncComponent(
      () => import('ee/vue_merge_request_widget/widgets/load_performance/index.vue'),
    ),
    MrMetricsWidget: defineAsyncComponent(
      () => import('ee/vue_merge_request_widget/widgets/metrics/index.vue'),
    ),
    MrSecurityWidgetEE: defineAsyncComponent(
      () =>
        import('ee/vue_merge_request_widget/widgets/security_reports/mr_widget_security_reports.vue'),
    ),
    MrSecurityWidgetCE: defineAsyncComponent(
      () =>
        import('~/vue_merge_request_widget/widgets/security_reports/mr_widget_security_reports.vue'),
    ),
    MrStatusChecksWidget: defineAsyncComponent(
      () => import('ee/vue_merge_request_widget/widgets/status_checks/index.vue'),
    ),
    MrLicenseComplianceWidget: defineAsyncComponent(
      () => import('ee/vue_merge_request_widget/widgets/license_compliance/index.vue'),
    ),
  },
  extends: CEWidgetApp,
  computed: {
    licenseComplianceWidget() {
      return this.mr?.enabledReports?.licenseScanning ? 'MrLicenseComplianceWidget' : undefined;
    },
    browserPerformanceWidget() {
      return this.mr.browserPerformance ? 'MrBrowserPerformanceWidget' : undefined;
    },
    loadPerformanceWidget() {
      return this.mr.loadPerformance ? 'MrLoadPerformanceWidget' : undefined;
    },
    metricsWidget() {
      return this.mr.metricsReportsPath ? 'MrMetricsWidget' : undefined;
    },
    statusChecksWidget() {
      return this.mr.apiStatusChecksPath && !this.mr.isNothingToMergeState
        ? 'MrStatusChecksWidget'
        : undefined;
    },
    securityReportsWidget() {
      return this.mr.canReadVulnerabilities ? 'MrSecurityWidgetEE' : 'MrSecurityWidgetCE';
    },
    // eslint-disable-next-line vue/no-unused-properties -- used by parent component CEWidgetApp render function
    widgets() {
      return [
        this.licenseComplianceWidget,
        this.codeQualityWidget,
        this.browserPerformanceWidget,
        this.loadPerformanceWidget,
        this.testReportWidget,
        this.metricsWidget,
        this.statusChecksWidget,
        this.terraformPlansWidget,
        this.securityReportsWidget,
        this.accessibilityWidget,
      ].filter((w) => w);
    },
  },
};
</script>
