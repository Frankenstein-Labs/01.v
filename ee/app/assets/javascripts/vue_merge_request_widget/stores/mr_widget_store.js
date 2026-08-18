import { convertObjectPropsToCamelCase, parseBoolean } from '~/lib/utils/common_utils';
import { s__ } from '~/locale';
import CEMergeRequestStore from '~/vue_merge_request_widget/stores/mr_widget_store';
import {
  DETAILED_MERGE_STATUS,
  MWCP_MERGE_STRATEGY,
  MTWCP_MERGE_STRATEGY,
} from '~/vue_merge_request_widget/constants';

export default class MergeRequestStore extends CEMergeRequestStore {
  constructor(data) {
    super(data);

    this.sastHelp = data.sast_help_path;
    this.containerScanningHelp = data.container_scanning_help_path;
    this.dastHelp = data.dast_help_path;
    this.apiFuzzingHelp = data.api_fuzzing_help_path;
    this.coverageFuzzingHelp = data.coverage_fuzzing_help_path;
    this.secretDetectionHelp = data.secret_detection_help_path;
    this.dependencyScanningHelp = data.dependency_scanning_help_path;
    this.canReadVulnerabilities = data.can_read_vulnerabilities;
    this.canReadVulnerabilityFeedback = data.can_read_vulnerability_feedback;
    this.canRetryExternalStatusChecks = data.can_retry_external_status_checks;
    this.securityReportsPipelineId = data.pipeline_id;
    this.securityReportsPipelineIid = data.pipeline_iid;
    this.createVulnerabilityFeedbackIssuePath = data.create_vulnerability_feedback_issue_path;
    this.createVulnerabilityFeedbackMergeRequestPath =
      data.create_vulnerability_feedback_merge_request_path;
    this.createVulnerabilityFeedbackDismissalPath =
      data.create_vulnerability_feedback_dismissal_path;
    this.appUrl = gon && gon.gitlab_url;
    this.licenseScanning = data.license_scanning;
    this.requirePasswordToApprove = data.require_password_to_approve;
    this.requireSamlAuthToApprove = data.require_saml_auth_to_approve;
    this.mergeRequestApproversAvailable = data.merge_request_approvers_available;
    this.aiCommitMessageEnabled = data.aiCommitMessageEnabled;
    this.pathLocksPath = data.path_locks_path;
    this.reportsTabPath = data.reportsTabPath;
    this.hasPolicies = data.hasPolicies || false;

    this.initBrowserPerformanceReport(data);
    this.initLoadPerformanceReport(data);
    this.initLicenseComplianceReport(data);

    this.metricsReportsPath = data.metrics_reports_path;

    this.enabledReports = convertObjectPropsToCamelCase(data.enabled_reports);

    this.apiApprovalSettingsPath = data.api_approval_settings_path;
    this.mergeTrainsPath = data.merge_trains_path;
    this.pipelineEtag = data.pipeline_etag;
  }

  setData(data, isRebased) {
    this.initGeo(data);

    this.mergePipelinesEnabled = Boolean(data.merge_pipelines_enabled);
    this.mergeTrainsSkipAllowed = data.merge_trains_skip_train_allowed;
    this.mergeTrainEnforced = parseBoolean(data.merge_train_enforced);
    this.policyViolation = data.policy_violation;
    this.jiraAssociation = data.jira_associations || {};
    this.canResolveWithAi = data.can_resolve_with_ai;

    super.setData(data, isRebased);
  }

  setGraphqlData(project) {
    super.setGraphqlData(project);

    const { mergeRequest } = project;

    this.mergeTrainsCount = project?.mergeTrains?.nodes[0]?.cars?.count;
    this.mergeTrainCar = mergeRequest.mergeTrainCar;
  }

  setGraphqlSubscriptionData(data) {
    super.setGraphqlSubscriptionData(data);

    this.mergeTrainsCount = data.mergeRequest?.project?.mergeTrains?.nodes[0]?.cars?.count;
    this.mergeTrainCar = data.mergeTrainCar;
  }

  setPaths(data) {
    // Paths are set on the first load of the page and not auto-refreshed
    super.setPaths(data);

    this.discoverProjectSecurityPath = data.discover_project_security_path;
    this.apiStatusChecksPath = data.api_status_checks_path;
    this.samlApprovalPath = data.saml_approval_path;
    this.securityPoliciesPath = data.security_policies_path;
  }

  initGeo(data) {
    this.isGeoSecondaryNode = this.isGeoSecondaryNode || data.is_geo_secondary_node;
    this.geoSecondaryHelpPath = this.geoSecondaryHelpPath || data.geo_secondary_help_path;
  }

  setApprovals(data) {
    super.setApprovals(data);

    this.approvalsLeft = data.approvalsLeft;

    this.setState();
  }

  get hasMergeChecksFailed() {
    if (
      this.hasApprovalsAvailable &&
      this.approvalsLeft &&
      this.preferredAutoMergeStrategy !== MWCP_MERGE_STRATEGY
    ) {
      return this.detailedMergeStatus === DETAILED_MERGE_STATUS.NOT_APPROVED;
    }

    if (this.detailedMergeStatus === DETAILED_MERGE_STATUS.BLOCKED_STATUS) return true;
    if (this.detailedMergeStatus === DETAILED_MERGE_STATUS.EXTERNAL_STATUS_CHECKS) return true;

    return super.hasMergeChecksFailed;
  }

  get preventMerge() {
    return (
      this.hasApprovalsAvailable &&
      this.isApprovalNeeded &&
      ![MWCP_MERGE_STRATEGY, MTWCP_MERGE_STRATEGY].includes(this.preferredAutoMergeStrategy)
    );
  }

  initBrowserPerformanceReport(data) {
    this.browserPerformance = data.browser_performance;
    this.browserPerformanceMetrics = {
      improved: [],
      degraded: [],
      same: [],
    };
  }

  initLoadPerformanceReport(data) {
    this.loadPerformance = data.load_performance;
    this.loadPerformanceMetrics = {
      improved: [],
      degraded: [],
      same: [],
    };
  }

  initLicenseComplianceReport({
    license_scanning_comparison_path,
    license_scanning_comparison_collapsed_path,
    api_approvals_path,
    license_scanning,
  }) {
    this.licenseCompliance = {
      license_scanning_comparison_path,
      license_scanning_comparison_collapsed_path,
      api_approvals_path,
      license_scanning,
    };
  }

  compareBrowserPerformanceMetrics(headMetrics, baseMetrics) {
    const headMetricsIndexed = MergeRequestStore.normalizeBrowserPerformanceMetrics(headMetrics);
    const baseMetricsIndexed = MergeRequestStore.normalizeBrowserPerformanceMetrics(baseMetrics);
    const improved = [];
    const degraded = [];
    const same = [];

    Object.keys(headMetricsIndexed).forEach((subject) => {
      const subjectMetrics = headMetricsIndexed[subject];
      Object.keys(subjectMetrics).forEach((metric) => {
        const headMetricData = subjectMetrics[metric];

        if (baseMetricsIndexed[subject] && baseMetricsIndexed[subject][metric]) {
          const baseMetricData = baseMetricsIndexed[subject][metric];
          const metricData = {
            name: metric,
            path: subject,
            score: headMetricData.value,
            delta: headMetricData.value - baseMetricData.value,
          };

          if (metricData.delta !== 0) {
            const isImproved =
              headMetricData.desiredSize === 'smaller'
                ? metricData.delta < 0
                : metricData.delta > 0;

            if (isImproved) {
              improved.push(metricData);
            } else {
              degraded.push(metricData);
            }
          } else {
            same.push(metricData);
          }
        }
      });
    });

    this.browserPerformanceMetrics = { improved, degraded, same };
  }

  // normalize browser performance metrics by indexing on performance subject and metric name
  static normalizeBrowserPerformanceMetrics(browserPerformanceData) {
    const indexedSubjects = {};
    browserPerformanceData.forEach(({ subject, metrics }) => {
      const indexedMetrics = {};
      metrics.forEach(({ name, ...data }) => {
        indexedMetrics[name] = data;
      });
      indexedSubjects[subject] = indexedMetrics;
    });

    return indexedSubjects;
  }

  compareLoadPerformanceMetrics(headMetrics, baseMetrics) {
    const headMetricsIndexed = MergeRequestStore.normalizeLoadPerformanceMetrics(headMetrics);
    const baseMetricsIndexed = MergeRequestStore.normalizeLoadPerformanceMetrics(baseMetrics);
    const improved = [];
    const degraded = [];
    const same = [];

    Object.keys(headMetricsIndexed).forEach((metric) => {
      const headMetricData = headMetricsIndexed[metric];
      if (metric in baseMetricsIndexed) {
        const baseMetricData = baseMetricsIndexed[metric];
        const metricData = {
          name: metric,
          score: headMetricData,
          delta: parseFloat((parseFloat(headMetricData) - parseFloat(baseMetricData)).toFixed(2)),
        };

        if (metricData.delta !== 0.0) {
          const isImproved = [s__('ciReport|RPS'), s__('ciReport|Checks')].includes(metric)
            ? metricData.delta > 0
            : metricData.delta < 0;

          if (isImproved) {
            improved.push(metricData);
          } else {
            degraded.push(metricData);
          }
        } else {
          same.push(metricData);
        }
      }
    });

    this.loadPerformanceMetrics = { improved, degraded, same };
  }

  // normalize load performance metrics for comsumption
  static normalizeLoadPerformanceMetrics(loadPerformanceData) {
    if (!('metrics' in loadPerformanceData)) return {};

    const { metrics } = loadPerformanceData;
    const indexedMetrics = {};

    Object.keys(loadPerformanceData.metrics).forEach((metric) => {
      switch (metric) {
        case 'http_reqs':
          indexedMetrics[s__('ciReport|RPS')] = metrics.http_reqs.rate;
          break;
        case 'http_req_waiting':
          indexedMetrics[s__('ciReport|TTFB P90')] = metrics.http_req_waiting['p(90)'];
          indexedMetrics[s__('ciReport|TTFB P95')] = metrics.http_req_waiting['p(95)'];
          break;
        case 'checks':
          indexedMetrics[s__('ciReport|Checks')] = `${(
            (metrics.checks.passes / (metrics.checks.passes + metrics.checks.fails)) *
            100.0
          ).toFixed(2)}%`;
          break;
        default:
          break;
      }
    });

    return indexedMetrics;
  }
}
