<script>
import { computed } from 'vue';
import { getSlotFunction, normalizeRender } from '~/lib/utils/vue3compat/normalize_render';
import { s__ } from '~/locale';
import SmartInterval from '~/smart_interval';
import enabledScansQuery from 'ee/vue_merge_request_widget/queries/enabled_scans.query.graphql';
import findingReportsComparerQuery from 'ee/vue_merge_request_widget/queries/finding_reports_comparer.query.graphql';
import {
  transformToEnabledScans,
  highlightsFromReport,
  updateFindingState,
} from 'ee/vue_merge_request_widget/widgets/security_reports/utils';
import { i18n, reportTypes } from 'ee/vue_merge_request_widget/widgets/security_reports/i18n';
import { CRITICAL, HIGH } from 'ee/vulnerabilities/constants';
import {
  EXTENSION_ICONS,
  SECURITY_SCAN_TO_REPORT_TYPE,
} from '~/vue_merge_request_widget/constants';
import { MAX_NEW_VULNERABILITIES } from 'ee/vue_merge_request_widget/widgets/security_reports/summary_text.vue';

const SCAN_TYPES_WITHOUT_CLUSTER_IMAGE_SCANNING = Object.keys(SECURITY_SCAN_TO_REPORT_TYPE).filter(
  (scanType) => scanType !== 'clusterImageScanning',
);
const POLL_INTERVAL = 3000;
const MAX_POLL_INTERVAL = 30000;
const TEST_ID = {
  SAST: 'sast-scan-report',
  DAST: 'dast-scan-report',
  DEPENDENCY_SCANNING: 'dependency-scan-report',
  SECRET_DETECTION: 'secret-detection-report',
  CONTAINER_SCANNING: 'container-scan-report',
  COVERAGE_FUZZING: 'coverage-fuzzing-report',
  API_FUZZING: 'api-fuzzing-report',
};

const reportHasError = (report) => report.full?.error || report.partial?.error;

export default normalizeRender({
  name: 'SecurityScansProvider',
  provide() {
    return {
      enabledScans: computed(() => this.enabledScans),
      enabledScansTransformed: computed(() => this.enabledScansTransformed),
      findingReports: computed(() => this.reports),
      findingReportsPerReportType: computed(() => this.reportsByScanType),
      totalNewFindings: computed(() => this.totalNewFindings),
      highlights: computed(() => this.highlights),
      topLevelErrorMessage: computed(() => this.topLevelErrorMessage),
      hasEnabledScans: computed(() => this.hasEnabledScans),
      isLoadingScans: computed(() => Boolean(this.loadingMessage)),
      loadingMessage: computed(() => this.loadingMessage),
      statusMessage: computed(() => this.statusMessage),
      statusIconName: computed(() => this.statusIconName),
      hasAtLeastOneReportWithMaxNewVulnerabilities: computed(
        () => this.hasAtLeastOneReportWithMaxNewVulnerabilities,
      ),
      hasFindingReportErrors: computed(() => this.hasSomeReportError),
      hasFindings: computed(() => this.hasFindings),
      updateFindingState: (findingUuid, newState) => this.updateFindingState(findingUuid, newState),
    };
  },
  inject: ['projectPath', 'iid'],
  props: {
    mr: {
      type: Object,
      required: true,
    },
  },
  data() {
    return {
      enabledScans: {
        full: {},
        partial: {},
      },
      enabledScansTransformed: [],
      reportsByScanType: {
        full: {},
        partial: {},
      },
      reportPollers: {},
      isFetchingReports: false,
      hasAtLeastOneReportWithMaxNewVulnerabilities: false,
      topLevelErrorMessage: '',
      pollingInterval: null,
    };
  },
  apollo: {
    enabledScans: {
      query: enabledScansQuery,
      variables() {
        return {
          fullPath: this.targetProjectFullPath,
          pipelineIid: this.pipelineIid,
        };
      },
      context: {
        featureCategory: 'vulnerability_management',
      },
      update({ project }) {
        if (!project?.pipeline) {
          return { full: {}, partial: {} };
        }

        const scans = project.pipeline;
        const isReady = scans.enabledSecurityScans?.ready === true;

        if (!isReady && !this.pollingInterval) {
          this.initPolling();
        }

        if (isReady && this.pollingInterval) {
          this.pollingInterval.destroy();
          this.pollingInterval = null;
        }

        this.enabledScansTransformed = transformToEnabledScans(scans);

        if (isReady && this.enabledScansTransformed.length > 0) {
          this.fetchAllFindingReports();
        }

        return {
          full: scans.enabledSecurityScans || {},
          partial: scans.enabledPartialSecurityScans || {},
        };
      },
      error() {
        this.topLevelErrorMessage = s__(
          'ciReport|Error while fetching enabled scans. Please try again later.',
        );
      },
      skip() {
        return !this.pipelineIid || !this.targetProjectFullPath;
      },
    },
  },
  computed: {
    pipelineIid() {
      return this.mr.pipeline?.iid;
    },
    targetProjectFullPath() {
      return this.mr.targetProjectFullPath;
    },
    hasActivePollers() {
      return Object.keys(this.reportPollers).length > 0;
    },
    isLoading() {
      if (this.topLevelErrorMessage) {
        return false;
      }

      return (
        this.$apollo.queries.enabledScans?.loading ||
        Boolean(this.pollingInterval) ||
        this.isFetchingReports ||
        (this.hasEnabledScans && this.reports.length === 0) ||
        this.hasActivePollers
      );
    },
    loadingMessage() {
      if (this.isLoading) {
        return i18n.loading;
      }
      return '';
    },
    statusMessage() {
      if (!this.pipelineIid) {
        // Handles both cases when no pipeline exists:
        // 1. No CI configured (ie. no .gitlab-ci.yml) — a pipeline will never run
        // 2. Pipeline coming soon — CI is configured, but the pipeline hasn't been created yet
        // Known limitation: there's no way for the FE to distinguish between these
        // without a BE change. See https://gitlab.com/gitlab-org/gitlab/-/issues/591723
        return s__(
          'ciReport|No security scan results. Either CI/CD is not configured or the pipeline is not yet complete.',
        );
      }
      if (this.topLevelErrorMessage) {
        return this.topLevelErrorMessage;
      }
      if (!this.hasEnabledScans) {
        return s__('ciReport|No security scans enabled.');
      }
      return '';
    },
    statusIconName() {
      if (this.topLevelErrorMessage) {
        return EXTENSION_ICONS.error;
      }
      if (
        !this.pipelineIid ||
        !this.hasEnabledScans ||
        this.totalNewFindings > 0 ||
        this.hasSomeReportError
      ) {
        return EXTENSION_ICONS.warning;
      }
      return EXTENSION_ICONS.success;
    },
    hasEnabledScans() {
      return SCAN_TYPES_WITHOUT_CLUSTER_IMAGE_SCANNING.some(
        (scanType) => this.enabledScans.full[scanType] || this.enabledScans.partial[scanType],
      );
    },
    reports() {
      return Object.keys(reportTypes)
        .filter(
          (reportType) =>
            this.reportsByScanType.full[reportType] || this.reportsByScanType.partial[reportType],
        )
        .map((reportType) => ({
          reportType,
          full: this.reportsByScanType.full[reportType],
          partial: this.reportsByScanType.partial[reportType],
        }));
    },
    totalNewFindings() {
      const sumFindings = (reports) =>
        Object.values(reports).reduce((sum, report) => sum + (report.numberOfNewFindings || 0), 0);

      return sumFindings(this.reportsByScanType.full) + sumFindings(this.reportsByScanType.partial);
    },
    highlights() {
      if (this.totalNewFindings === 0) {
        return {};
      }

      const initialHighlights = { [CRITICAL]: 0, [HIGH]: 0, other: 0 };

      const combinedHighlights = this.reports.reduce(
        (acc, report) => highlightsFromReport(report, acc),
        initialHighlights,
      );

      return combinedHighlights;
    },
    hasAllReportError() {
      return this.reports.length > 0 && this.reports.every(reportHasError);
    },
    hasSomeReportError() {
      return this.reports.some(reportHasError);
    },
    hasFindings() {
      return this.reports.some(
        ({ full, partial }) =>
          full?.numberOfNewFindings ||
          full?.numberOfFixedFindings ||
          partial?.numberOfNewFindings ||
          partial?.numberOfFixedFindings,
      );
    },
  },
  beforeDestroy() {
    if (this.pollingInterval) {
      this.pollingInterval.destroy();
    }
    Object.values(this.reportPollers).forEach((poller) => poller.destroy());
  },
  methods: {
    initPolling() {
      this.pollingInterval = new SmartInterval({
        callback: () => this.$apollo.queries.enabledScans.refetch(),
        startingInterval: POLL_INTERVAL,
        incrementByFactorOf: 1,
        immediateExecution: true,
      });
    },
    async fetchAllFindingReports() {
      this.isFetchingReports = true;
      const fetchPromises = this.enabledScansTransformed.map(({ reportType, scanMode }) =>
        this.fetchFindingReports(reportType, scanMode),
      );
      await Promise.all(fetchPromises);
      this.isFetchingReports = false;

      if (this.hasAllReportError && !this.topLevelErrorMessage) {
        this.topLevelErrorMessage = s__('ciReport|Security reports failed loading results');
      }
    },
    fetchFindingReports(reportType, scanMode) {
      const scanModeKey = scanMode === 'PARTIAL' ? 'partial' : 'full';
      const defaultReportStructure = {
        reportType,
        reportTypeDescription: reportTypes[reportType],
        numberOfNewFindings: 0,
        numberOfFixedFindings: 0,
        added: [],
        fixed: [],
      };

      return this.$apollo
        .query({
          query: findingReportsComparerQuery,
          context: {
            featureCategory: 'vulnerability_management',
          },
          variables: {
            fullPath: this.targetProjectFullPath,
            iid: String(this.mr.iid),
            reportType,
            scanMode,
          },
          fetchPolicy: 'network-only',
        })
        .then((result) => {
          const data = result.data?.project?.mergeRequest?.findingReportsComparer;

          if (data?.status !== 'PARSED') {
            this.startReportPolling(reportType, scanMode);
            return;
          }

          this.stopReportPolling(reportType, scanMode);

          // GraphQL responses are read-only, so clone to allow state updates via updateFindingState
          // that shows the dismissed badge immediately without a refetch
          const added = data.report?.added?.map((finding) => ({ ...finding })) || [];
          const fixed = data.report?.fixed?.map((finding) => ({ ...finding })) || [];

          if (added.length === MAX_NEW_VULNERABILITIES) {
            this.hasAtLeastOneReportWithMaxNewVulnerabilities = true;
          }

          const report = {
            ...defaultReportStructure,
            ...data,
            added,
            fixed,
            findings: [...added, ...fixed],
            numberOfNewFindings: added.length,
            numberOfFixedFindings: fixed.length,
            testId: TEST_ID[reportType],
          };

          this.reportsByScanType[scanModeKey] = {
            ...this.reportsByScanType[scanModeKey],
            [reportType]: report,
          };
        })
        .catch((error) => {
          this.stopReportPolling(reportType, scanMode);

          const report = { ...defaultReportStructure, error: true };

          this.reportsByScanType[scanModeKey] = {
            ...this.reportsByScanType[scanModeKey],
            [reportType]: report,
          };

          if (error.graphQLErrors?.some((err) => err.extensions?.code === 'PARSING_ERROR')) {
            this.topLevelErrorMessage = s__(
              'ciReport|Parsing schema failed. Check the validity of your .gitlab-ci.yml content.',
            );
          }
        });
    },
    startReportPolling(reportType, scanMode) {
      const key = `${reportType}_${scanMode}`;

      if (this.reportPollers[key]) return;

      this.reportPollers[key] = new SmartInterval({
        callback: () => this.fetchFindingReports(reportType, scanMode),
        startingInterval: POLL_INTERVAL,
        maxInterval: MAX_POLL_INTERVAL,
        incrementByFactorOf: 1.5,
        immediateExecution: false,
      });
    },
    updateFindingState(findingUuid, newState) {
      updateFindingState(this.reportsByScanType, findingUuid, newState);
    },
    stopReportPolling(reportType, scanMode) {
      const key = `${reportType}_${scanMode}`;
      if (this.reportPollers[key]) {
        this.reportPollers[key].destroy();

        // Don't use `delete` to remove pollers: `delete this.reportPollers[key]`
        // which causes computed properties like `hasActivePollers` to go stale.
        // Reassign the object instead to keep reactivity working.
        // See comment for more details: https://gitlab.com/gitlab-org/gitlab/-/merge_requests/221772#note_3088847523
        const { [key]: removed, ...remainingPollers } = this.reportPollers;
        this.reportPollers = remainingPollers;
      }
    },
  },
  render() {
    return getSlotFunction(this)?.();
  },
});
</script>
