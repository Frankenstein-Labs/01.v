<script>
import { defineAsyncComponent } from 'vue';
import { visitUrl, joinPaths } from '~/lib/utils/url_utility';
import {
  SECURITY_SCAN_ROUTE,
  CLICK_VIEW_REPORT_ON_MERGE_REQUEST_WIDGET,
  TRACKING_LABEL_BY_ROUTE,
} from '~/merge_requests/reports/constants';
import { historyPushState } from '~/lib/utils/common_utils';
import { InternalEvents } from '~/tracking';
import MrWidget from '~/vue_merge_request_widget/components/widget/widget.vue';
import { s__ } from '~/locale';
import enabledScansQuery from 'ee/vue_merge_request_widget/queries/enabled_scans.query.graphql';
import SummaryHighlights from 'ee/vue_shared/security_reports/components/summary_highlights.vue';
import {
  EXTENSION_ICONS,
  SECURITY_SCAN_TO_REPORT_TYPE,
} from '~/vue_merge_request_widget/constants';
import { helpPagePath } from '~/helpers/help_page_helper';
import SmartInterval from '~/smart_interval';
import { CRITICAL, HIGH } from 'ee/vulnerabilities/constants';
import findingReportsComparerQuery from 'ee/vue_merge_request_widget/queries/finding_reports_comparer.query.graphql';
import {
  HTTP_STATUS_INTERNAL_SERVER_ERROR,
  HTTP_STATUS_OK,
  HTTP_STATUS_ACCEPTED,
} from '~/lib/utils/http_status';
import SummaryText, { MAX_NEW_VULNERABILITIES } from './summary_text.vue';
import ReportDetails from './mr_widget_security_report_details.vue';
import { i18n, reportTypes } from './i18n';
import { highlightsFromReport, transformToEnabledScans } from './utils';

const POLL_INTERVAL = 3000;
const AI_COMMENT_FALLBACK_TIMEOUT_MS = 3000;

export default {
  name: 'WidgetSecurityReports',
  components: {
    VulnerabilityFindingModal: defineAsyncComponent(
      () => import('ee/security_dashboard/components/pipeline/vulnerability_finding_modal.vue'),
    ),
    MrWidget,
    ReportDetails,
    SummaryText,
    SummaryHighlights,
  },
  i18n,
  mixins: [InternalEvents.mixin()],
  props: {
    mr: {
      type: Object,
      required: true,
    },
  },
  emits: ['loaded'],
  data() {
    return {
      isLoading: true,
      hasAtLeastOneReportWithMaxNewVulnerabilities: false,
      modalData: null,
      topLevelErrorMessage: '',
      /**
       * Example data structure with all available fields:
       *
       * {
       *   full: {
       *     SAST: {
       *       reportType: 'SAST',
       *       reportTypeDescription: 'SAST',
       *.      numberOfNewFindings: 2,
       *       numberOfFixedFindings: 2,
       *       added: [Array], // typeof Finding
       *       fixed: [Array], // typeof Finding
       *       findings: [Array] // typeof Finding,
       *       testId: 'sast-scan-report'
       *     }
       *   }
       * }
       */
      reportsByScanType: {
        full: {},
        partial: {},
      },
      enabledScans: {
        partial: {},
        full: this.mr.enabledReports || {},
      },
      enabledScansTransformed: [],
    };
  },
  computed: {
    /**
     * Returns an array of reports in the following format:
     *
     * [
     *   { reportType: 'SAST', full: Report, partial: Report },
     *   { reportType: 'DAST', full: Report, partial: Report },
     *   // ...
     * ]
     */
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

    isCollapsible() {
      return this.reports.some(
        ({ full, partial }) =>
          full?.numberOfNewFindings ||
          full?.numberOfFixedFindings ||
          partial?.numberOfNewFindings ||
          partial?.numberOfFixedFindings,
      );
    },

    highlights() {
      if (!this.isCollapsible) {
        return {};
      }

      const highlights = {
        [HIGH]: 0,
        [CRITICAL]: 0,
        other: 0,
      };

      this.reports.forEach((report) => highlightsFromReport(report, highlights));

      return highlights;
    },

    totalNewFindings() {
      return this.reports.reduce((counter, current) => {
        return (
          counter +
          (current.full?.numberOfNewFindings || 0) +
          (current.partial?.numberOfNewFindings || 0)
        );
      }, 0);
    },

    statusIconName() {
      if (this.totalNewFindings > 0) {
        return EXTENSION_ICONS.warning;
      }

      if (this.topLevelErrorMessage) {
        return EXTENSION_ICONS.error;
      }

      return EXTENSION_ICONS.success;
    },

    actionButtons() {
      return [
        {
          text: s__('MrReports|View report'),
          href: joinPaths(this.mr.reportsTabPath, SECURITY_SCAN_ROUTE),
          onClick: (action, e) => {
            e.preventDefault();
            this.trackEvent(CLICK_VIEW_REPORT_ON_MERGE_REQUEST_WIDGET, {
              label: TRACKING_LABEL_BY_ROUTE[SECURITY_SCAN_ROUTE],
            });
            window.history.pushState(null, null, action.href);
            window.dispatchEvent(new PopStateEvent('popstate'));
          },
        },
      ];
    },

    hasEnabledScans() {
      // clusterImageScanning is excluded as it scans existing clusters rather than MR-specific changes
      const scanTypesWithoutClusterImageScanning = Object.keys(SECURITY_SCAN_TO_REPORT_TYPE).filter(
        (scanType) => scanType !== 'clusterImageScanning',
      );

      return scanTypesWithoutClusterImageScanning.some(
        (scanType) => this.enabledScans.full[scanType] || this.enabledScans.partial[scanType],
      );
    },

    pipelineIid() {
      const iid = this.modalData.vulnerability.foundByPipelineIid;
      return iid ? Number(iid) : null;
    },
    branchRef() {
      return this.mr.sourceBranch;
    },

    shouldRenderMrWidget() {
      if (this.isLoadingEnabledScans) {
        return false;
      }

      return !this.mr.isPipelineActive && this.hasEnabledScans;
    },

    isLoadingEnabledScans() {
      return this.$apollo.queries.enabledScans?.loading || this.$options.pollingInterval;
    },
  },
  apollo: {
    enabledScans: {
      query: enabledScansQuery,
      variables() {
        return {
          fullPath: this.mr.targetProjectFullPath,
          pipelineIid: this.mr.pipeline?.iid,
        };
      },
      context: {
        featureCategory: 'vulnerability_management',
      },
      update({ project }) {
        // Return early if pipeline is not defined
        if (!project?.pipeline) {
          return { full: {}, partial: {} };
        }

        const scans = project.pipeline;

        // We need to check only one of these because they make the same query in the backend
        const isReady = scans.enabledSecurityScans?.ready === true;

        if (!isReady && !this.$options.pollingInterval) {
          this.initPolling();
        }

        if (isReady && this.$options.pollingInterval) {
          this.$options.pollingInterval.destroy();
          this.$options.pollingInterval = undefined;
        }

        this.enabledScansTransformed = transformToEnabledScans(scans);

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
        return (
          !this.mr.pipeline?.iid ||
          !this.mr.targetProjectFullPath ||
          Boolean(this.mr.pipeline.active)
        );
      },
    },
  },
  beforeDestroy() {
    this.cleanUpResolveWithAiHandlers();

    if (this.$options.pollingInterval) {
      this.$options.pollingInterval.destroy();
    }
  },
  methods: {
    initPolling() {
      this.$options.pollingInterval = new SmartInterval({
        callback: () => this.$apollo.queries.enabledScans.refetch(),
        startingInterval: POLL_INTERVAL,
        incrementByFactorOf: 1,
        immediateExecution: true,
      });
    },

    handleResolveWithAiSuccess(commentUrl) {
      // the note's id is the hash of the url and also the DOM id which we want to scroll to
      const [, commentNoteId] = commentUrl.split('#');

      const isCommentOnPage = () => document.getElementById(commentNoteId) !== null;
      const closeModalAndScrollToComment = () => {
        this.clearModalData();
        visitUrl(commentUrl);
      };

      if (isCommentOnPage()) {
        closeModalAndScrollToComment();
        return;
      }

      // as a fallback we set a timeout and then manually do a hard page reload
      this.commentNoteFallbackTimeout = setTimeout(() => {
        this.cleanUpResolveWithAiHandlers();
        historyPushState(commentUrl);
        window.location.reload();
      }, AI_COMMENT_FALLBACK_TIMEOUT_MS);

      // observe the DOM and scroll to the comment when it's added
      this.commentMutationObserver = new MutationObserver((mutationList) => {
        for (const mutation of mutationList) {
          // check if the added notes within the mutation contains the comment we're looking for
          if (mutation.addedNodes.length > 0 && isCommentOnPage()) {
            this.cleanUpResolveWithAiHandlers();
            closeModalAndScrollToComment();
            return;
          }
        }
      });

      this.commentMutationObserver.observe(document.getElementById('notes') || document.body, {
        childList: true,
        subtree: true,
      });
    },

    cleanUpResolveWithAiHandlers() {
      if (this.commentNoteFallbackTimeout) {
        clearTimeout(this.commentNoteFallbackTimeout);
      }
      if (this.commentMutationObserver) {
        this.commentMutationObserver.disconnect();
      }
    },

    updateFindingState(state) {
      this.modalData.vulnerability.state = state;
    },

    handleIsLoading(value) {
      this.isLoading = value;
    },

    fetchCollapsedData() {
      return this.enabledScansTransformed.map(({ reportType, scanMode }) => () => {
        return this.fetchFindingReports(reportType, scanMode);
      });
    },

    fetchFindingReports(reportType, scanMode = 'FULL') {
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
            fullPath: this.mr.targetProjectFullPath,
            iid: String(this.mr.iid),
            reportType,
            scanMode,
          },
          fetchPolicy: 'network-only',
        })
        .then((result) => {
          const data = result.data?.project?.mergeRequest?.findingReportsComparer;

          if (data?.status !== 'PARSED') {
            // Need to pass "poll-interval" header to trigger MrWidget's polling mechanism
            return {
              headers: { 'poll-interval': POLL_INTERVAL },
              status: HTTP_STATUS_ACCEPTED,
              data: {},
            };
          }

          // GraphQL responses are read-only, so clone to enable mutations
          // Allows "updateFindingState" to show dismissed badge changes immediately without refresh
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
            testId: this.$options.testId[reportType],
          };

          this.reportsByScanType[scanModeKey] = {
            ...this.reportsByScanType[scanModeKey],
            [reportType]: report,
          };
          this.$emit('loaded', added.length);

          // Pass empty header (no "poll-interval") to stop MrWidget's polling mechanism
          return { headers: {}, status: HTTP_STATUS_OK, data: report };
        })
        .catch((error) => {
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

          return { headers: {}, status: HTTP_STATUS_INTERNAL_SERVER_ERROR, data: report };
        });
    },

    setModalData(finding) {
      this.modalData = {
        error: null,
        title: finding.title,
        vulnerability: finding,
      };
    },

    clearModalData() {
      this.modalData = null;
    },
  },
  widgetHelpPopover: {
    options: { title: i18n.helpPopoverTitle },
    content: {
      text: i18n.helpPopoverContent,
      learnMorePath: helpPagePath('user/application_security/detect/security_scanning_results', {
        anchor: 'merge-request-reports',
      }),
    },
  },
  testId: {
    SAST: 'sast-scan-report',
    DAST: 'dast-scan-report',
    DEPENDENCY_SCANNING: 'dependency-scan-report',
    SECRET_DETECTION: 'secret-detection-report',
    CONTAINER_SCANNING: 'container-scan-report',
    COVERAGE_FUZZING: 'coverage-fuzzing-report',
    API_FUZZING: 'api-fuzzing-report',
  },
  pollingInterval: undefined,
};
</script>

<template>
  <mr-widget
    v-if="shouldRenderMrWidget"
    :error-text="topLevelErrorMessage || $options.i18n.error"
    :has-error="Boolean(topLevelErrorMessage)"
    :fetch-collapsed-data="fetchCollapsedData"
    :status-icon-name="statusIconName"
    :widget-name="$options.name"
    :is-collapsible="false"
    :expand-button-label="s__('SecurityReports|Expand security scanning details')"
    :collapse-button-label="s__('SecurityReports|Collapse security scanning details')"
    :help-popover="$options.widgetHelpPopover"
    :action-buttons="actionButtons"
    multi-polling
    data-testid="vulnerability-report-grouped"
    @is-loading="handleIsLoading"
  >
    <template #summary>
      <summary-text
        :total-new-vulnerabilities="totalNewFindings"
        :is-loading="isLoading"
        :show-at-least-hint="hasAtLeastOneReportWithMaxNewVulnerabilities"
      />
      <summary-highlights v-if="!isLoading && totalNewFindings > 0" :highlights="highlights" />
    </template>
    <template #content>
      <vulnerability-finding-modal
        v-if="modalData"
        :finding-uuid="modalData.vulnerability.uuid"
        :pipeline-iid="pipelineIid"
        :branch-ref="branchRef"
        :project-full-path="mr.targetProjectFullPath"
        :source-project-full-path="mr.sourceProjectFullPath"
        :show-ai-resolution="true"
        :merge-request-id="mr.id"
        data-testid="vulnerability-finding-modal"
        @hidden="clearModalData"
        @dismissed="updateFindingState('dismissed')"
        @detected="updateFindingState('detected')"
        @resolve-with-ai-success="handleResolveWithAiSuccess"
      />
      <report-details
        v-for="report in reports"
        :key="report.reportType"
        :widget-name="$options.name"
        :report="report"
        :mr="mr"
        @modal-data="setModalData"
      />
    </template>
  </mr-widget>
  <!--
    We must fetch enabled scans before mounting the MR widget because the widget
    immediately calls `fetchCollapsedData` on mount. Since `fetchCollapsedData`
    needs the enabled scans result to determine which endpoints to query, we delay
    mounting until the enabled scans have been fetched.

    In order to display the loading state in the meantime, we mount this
    <mr-widget> component instead of the one above.
    -->
  <mr-widget
    v-else-if="isLoadingEnabledScans"
    key="mr-widget-loading"
    :is-collapsible="false"
    :widget-name="$options.name"
    loading-state="collapsed"
    data-testid="vulnerability-report-grouped"
  >
    <template #summary>
      <summary-text is-loading :total-new-vulnerabilities="0" />
    </template>
  </mr-widget>
</template>
