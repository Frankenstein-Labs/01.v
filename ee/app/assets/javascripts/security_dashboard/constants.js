import { __, s__ } from '~/locale';
import { helpPagePath } from '~/helpers/help_page_helper';

export const DASHBOARD_TYPE_PROJECT = 'project';
export const DASHBOARD_TYPE_PIPELINE = 'pipeline';
export const DASHBOARD_TYPE_GROUP = 'group';
export const DASHBOARD_TYPE_INSTANCE = 'instance';
export const DASHBOARD_TYPE_ORGANIZATION = 'organization';

export const SEVERITY_LEVEL_CRITICAL = 'critical';
export const SEVERITY_LEVEL_HIGH = 'high';
export const SEVERITY_LEVEL_UNKNOWN = 'unknown';
export const SEVERITY_LEVEL_MEDIUM = 'medium';
export const SEVERITY_LEVEL_LOW = 'low';
export const SEVERITY_LEVEL_INFO = 'info';

export const SEVERITY_LEVELS = {
  [SEVERITY_LEVEL_CRITICAL]: s__('severity|Critical'),
  [SEVERITY_LEVEL_HIGH]: s__('severity|High'),
  [SEVERITY_LEVEL_MEDIUM]: s__('severity|Medium'),
  [SEVERITY_LEVEL_LOW]: s__('severity|Low'),
  [SEVERITY_LEVEL_INFO]: s__('severity|Info'),
  [SEVERITY_LEVEL_UNKNOWN]: s__('severity|Unknown'),
};

export const SEVERITY_LEVELS_KEYS = Object.keys(SEVERITY_LEVELS);

// The GraphQL type (`VulnerabilitySeverity`) for severities is an enum with uppercase values
export const SEVERITY_LEVELS_GRAPHQL = Object.keys(SEVERITY_LEVELS).map((k) => k.toUpperCase());

export const REPORT_TYPES_DEFAULT = {
  api_fuzzing: s__('ciReport|API Fuzzing'),
  container_scanning: s__('ciReport|Container Scanning'),
  coverage_fuzzing: s__('ciReport|Coverage Fuzzing'),
  dast: s__('ciReport|DAST'),
  dependency_scanning: s__('ciReport|Dependency Scanning'),
  sast: s__('ciReport|SAST'),
  secret_detection: s__('ciReport|Secret Detection'),
};

export const REPORT_TYPES_DEFAULT_KEYS = Object.keys(REPORT_TYPES_DEFAULT);

export const REPORT_TYPES_CONTAINER_SCANNING_FOR_REGISTRY = {
  container_scanning_for_registry: s__('ciReport|Container Scanning for Registry'),
};

export const REPORT_TYPES_WITH_CLUSTER_IMAGE = {
  ...REPORT_TYPES_DEFAULT,
  cluster_image_scanning: s__('ciReport|Cluster Image Scanning'),
};

export const REPORT_TYPES_WITH_MANUALLY_ADDED = {
  ...REPORT_TYPES_DEFAULT,
  generic: s__('ciReport|Manually added'),
};

export const REPORT_TYPES_ALL = {
  ...REPORT_TYPES_DEFAULT,
  ...REPORT_TYPES_WITH_CLUSTER_IMAGE,
  ...REPORT_TYPES_WITH_MANUALLY_ADDED,
};

export const DEFAULT_SCANNER = 'GitLab';
export const SCANNER_ID_PREFIX = 'gid://gitlab/Vulnerabilities::Scanner/';

export const DOC_PATH_VULNERABILITY_DETAILS = helpPagePath(
  'user/application_security/vulnerabilities/_index',
);
export const DOC_PATH_VULNERABILITY_REPORT = helpPagePath(
  'user/application_security/vulnerability_report/_index',
);
export const DOC_PATH_SECURITY_CONFIGURATION = helpPagePath(
  'user/application_security/detect/security_configuration',
  { anchor: 'with-the-ui' },
);
export const DOC_PATH_SECURITY_SCANNER_INTEGRATION_REPORT = helpPagePath(
  'development/integrations/secure',
  { anchor: 'report' },
);
export const DOC_PATH_SECURITY_SCANNER_INTEGRATION_RETENTION_PERIOD = helpPagePath(
  'user/application_security/detect/security_scanning_results',
);

export const DOC_PATH_PROJECT_SECURITY_DASHBOARD = helpPagePath(
  'user/application_security/security_dashboard/_index',
  { anchor: 'project-security-dashboard' },
);

export const DOC_PATH_SAST_FALSE_POSITIVE_DETECTION = helpPagePath(
  '/user/duo_agent_platform/flows/foundational_flows/sast_false_positive_detection',
);

export const SEVERITY_GROUP_F = 'F';
export const SEVERITY_GROUP_D = 'D';
export const SEVERITY_GROUP_C = 'C';
export const SEVERITY_GROUP_B = 'B';
export const SEVERITY_GROUP_A = 'A';

export const SEVERITY_GROUPS = [
  {
    type: SEVERITY_GROUP_F,
    description: __('Projects with critical vulnerabilities'),
    warning: __('Critical vulnerabilities present'),
    severityLevels: [SEVERITY_LEVEL_CRITICAL],
  },
  {
    type: SEVERITY_GROUP_D,
    description: __('Projects with high or unknown vulnerabilities'),
    warning: __('High or unknown vulnerabilities present'),
    severityLevels: [SEVERITY_LEVEL_HIGH, SEVERITY_LEVEL_UNKNOWN],
  },
  {
    type: SEVERITY_GROUP_C,
    description: __('Projects with medium vulnerabilities'),
    warning: __('Medium vulnerabilities present'),
    severityLevels: [SEVERITY_LEVEL_MEDIUM],
  },
  {
    type: SEVERITY_GROUP_B,
    description: __('Projects with low vulnerabilities'),
    warning: __('Low vulnerabilities present'),
    severityLevels: [SEVERITY_LEVEL_LOW],
  },
  {
    type: SEVERITY_GROUP_A,
    description: __('Projects with no vulnerabilities and security scanning enabled'),
    warning: __('No vulnerabilities present'),
    severityLevels: [],
  },
];

export const VULNERABILITY_DETAIL_CODE_FLOWS = 'VulnerabilityDetailCodeFlows';

export const EXPORT_NOT_READY_ERROR_CODE = 'EXPORT_NOT_READY';
export const EXPORT_ERROR_MESSAGE_CHART_LOADING = s__(
  'SecurityReports|Chart is still loading. Please try again after all data has loaded.',
);
export const EXPORT_ERROR_MESSAGE_CHART_FAILURE = s__(
  'SecurityReports|Chart failed to initialize. Please refresh the page and try again.',
);

export const DASHBOARD_LOOKBACK_DAYS = 30;

export const FINDING_MODAL_ERROR_CONTAINER_ID = 'finding-modal-error-container';
