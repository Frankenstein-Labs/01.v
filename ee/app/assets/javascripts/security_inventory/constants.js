import { GL_COLOR_NEUTRAL_100 } from '@gitlab/ui/src/tokens/build/js/tokens';
import { s__, __ } from '~/locale';
import { CRITICAL, HIGH, MEDIUM, LOW, INFO, UNKNOWN } from 'ee/vulnerabilities/constants';
import {
  OPERATOR_IS,
  OPERATOR_LESS_THAN_OR_EQUAL,
  OPERATOR_GREATER_THAN_OR_EQUAL,
} from '~/vue_shared/components/filtered_search_bar/constants';

export const DEPENDENCY_SCANNING_KEY = 'DEPENDENCY_SCANNING';
export const SAST_KEY = 'SAST';
export const SAST_ADVANCED_KEY = 'SAST_ADVANCED';
export const SECRET_DETECTION_KEY = 'SECRET_DETECTION';
export const SECRET_DETECTION_PIPELINE_BASED_KEY = 'SECRET_DETECTION_PIPELINE_BASED';
export const SECRET_PUSH_PROTECTION_KEY = 'SECRET_DETECTION_SECRET_PUSH_PROTECTION';
export const CONTAINER_SCANNING_KEY = 'CONTAINER_SCANNING';
export const CONTAINER_SCANNING_FOR_REGISTRY_KEY = 'CONTAINER_SCANNING_FOR_REGISTRY';
export const DAST_KEY = 'DAST';
export const SAST_IAC_KEY = 'SAST_IAC';

export const SIDEBAR_WIDTH_INITIAL = 300;
export const SIDEBAR_WIDTH_MINIMUM = 200;
export const SIDEBAR_WIDTH_STORAGE_KEY = 'security_inventory_sidebar_width';
export const SIDEBAR_VISIBLE_STORAGE_KEY = 'security_inventory_sidebar_visible';
export const SIDEBAR_INDENTATION_INCREMENT = 20; // pixels
export const SIDEBAR_SEARCH_DEBOUNCE = 500; // milliseconds

const SAST_LABEL = s__('SecurityInventory|SAST');
const DAST_LABEL = s__('SecurityInventory|DAST');
const SAST_IAC_LABEL = s__('SecurityInventory|IaC');
const SECRET_DETECTION_LABEL = s__('SecurityInventory|SD');
const DEPENDENCY_SCANNING_LABEL = s__('SecurityInventory|DS');
const CONTAINER_SCANNING_LABEL = s__('SecurityInventory|CS');

export const SCANNER_TYPES = {
  [DEPENDENCY_SCANNING_KEY]: {
    textLabel: DEPENDENCY_SCANNING_LABEL,
    name: s__('SecurityInventory|Dependency scanning'),
  },
  [SAST_KEY]: {
    textLabel: SAST_LABEL,
    name: s__('SecurityInventory|Static application security testing (SAST)'),
  },
  [SAST_ADVANCED_KEY]: {
    textLabel: SAST_LABEL,
    name: s__('SecurityInventory|Static application security testing (SAST)'),
  },
  [SECRET_DETECTION_KEY]: {
    textLabel: SECRET_DETECTION_LABEL,
    name: s__('SecurityInventory|Secret detection'),
  },
  [SECRET_PUSH_PROTECTION_KEY]: {
    textLabel: SECRET_DETECTION_LABEL,
    name: s__('SecurityInventory|Secret push protection'),
  },
  [CONTAINER_SCANNING_KEY]: {
    textLabel: CONTAINER_SCANNING_LABEL,
    name: s__('SecurityInventory|Container scanning'),
  },
  [CONTAINER_SCANNING_FOR_REGISTRY_KEY]: {
    textLabel: CONTAINER_SCANNING_LABEL,
    name: s__('SecurityInventory|Container scanning'),
  },
  [DAST_KEY]: {
    textLabel: DAST_LABEL,
    name: s__('SecurityInventory|Dynamic application security testing (DAST)'),
  },
  [SAST_IAC_KEY]: {
    textLabel: SAST_IAC_LABEL,
    name: s__('SecurityInventory|Infrastructure as code scanning (IaC)'),
  },
};

export const SCANNER_POPOVER_GROUPS = {
  [DEPENDENCY_SCANNING_KEY]: ['DEPENDENCY_SCANNING'],
  [SAST_KEY]: ['SAST', 'SAST_ADVANCED'],
  [SECRET_DETECTION_KEY]: [SECRET_DETECTION_PIPELINE_BASED_KEY, SECRET_PUSH_PROTECTION_KEY],
  [CONTAINER_SCANNING_KEY]: ['CONTAINER_SCANNING', 'CONTAINER_SCANNING_FOR_REGISTRY'],
  [DAST_KEY]: ['DAST'],
  [SAST_IAC_KEY]: ['SAST_IAC'],
};

export const SCANNER_POPOVER_LABELS = {
  [SAST_KEY]: s__('SecurityInventory|Basic SAST'),
  [SAST_ADVANCED_KEY]: s__('SecurityInventory|GitLab Advanced SAST'),
  [SECRET_DETECTION_PIPELINE_BASED_KEY]: s__('SecurityInventory|Pipeline secret detection'),
  [SECRET_PUSH_PROTECTION_KEY]: s__('SecurityInventory|Secret push protection'),
  [CONTAINER_SCANNING_KEY]: s__('SecurityInventory|Container scanning (standard)'),
  [CONTAINER_SCANNING_FOR_REGISTRY_KEY]: s__('SecurityInventory|Container scanning for registry'),
};

export const SEVERITY_SEGMENTS = [CRITICAL, HIGH, MEDIUM, LOW];

export const VULNERABILITY_REPORT_PATHS = {
  PROJECT: '/-/security/vulnerability_report',
  GROUP: '/-/security/vulnerabilities',
};

export const PROJECT_SECURITY_CONFIGURATION_PATH = '/-/security/configuration';
export const PROJECT_VULNERABILITY_REPORT_PATH = '/-/security/vulnerability_report';
export const GROUP_VULNERABILITY_REPORT_PATH = '/-/security/vulnerabilities';
export const PROJECT_PIPELINE_JOB_PATH = '/-/jobs';

export const VISIBLE_ATTRIBUTE_COUNT = 3;
export const LIGHT_GRAY = GL_COLOR_NEUTRAL_100;

export const SCANNER_FILTER_LABELS = {
  [DEPENDENCY_SCANNING_KEY]: s__('SecurityInventory|Dependency scanning (DS)'),
  [SAST_KEY]: s__('SecurityInventory|Basic SAST (SAST)'),
  [SAST_ADVANCED_KEY]: s__('SecurityInventory|Advanced SAST (SAST)'),
  [SECRET_DETECTION_PIPELINE_BASED_KEY]: s__('SecurityInventory|Pipeline secret detection (SD)'),
  [SECRET_PUSH_PROTECTION_KEY]: s__('SecurityInventory|Secret push protection (SD)'),
  [CONTAINER_SCANNING_KEY]: s__('SecurityInventory|Container scanning (CS)'),
  [CONTAINER_SCANNING_FOR_REGISTRY_KEY]: s__(
    'SecurityInventory|Container scanning for registry (CS)',
  ),
  [DAST_KEY]: s__('SecurityInventory|Dynamic Application Security Testing (DAST)'),
  [SAST_IAC_KEY]: s__('SecurityInventory|Infrastructure as Code (IaC)'),
};
export const SCANNER_SEGMENT_LABELS = {
  [DEPENDENCY_SCANNING_KEY]: s__('SecurityInventory|Dependency scanning'),
  [SAST_KEY]: s__('SecurityInventory|Basic SAST'),
  [SAST_ADVANCED_KEY]: s__('SecurityInventory|Advanced SAST'),
  [SECRET_DETECTION_PIPELINE_BASED_KEY]: s__('SecurityInventory|Secret detection'),
  [SECRET_PUSH_PROTECTION_KEY]: s__('SecurityInventory|Secret push protection'),
  [CONTAINER_SCANNING_KEY]: s__('SecurityInventory|Container scanning'),
  [CONTAINER_SCANNING_FOR_REGISTRY_KEY]: s__('SecurityInventory|Container scanning for registry'),
  [DAST_KEY]: s__('SecurityInventory|Dynamic Application Security Testing (DAST)'),
  [SAST_IAC_KEY]: s__('SecurityInventory|Infrastructure as Code (IaC)'),
};

export const TOOL_ENABLED = 'SUCCESS';
export const TOOL_NOT_ENABLED = 'NOT_CONFIGURED';
export const TOOL_FAILED = 'FAILED';
export const TOOL_STALE = 'STALE';
export const TOOL_FILTER_LABELS = {
  [TOOL_ENABLED]: __('Enabled'),
  [TOOL_NOT_ENABLED]: __('Not enabled'),
  [TOOL_FAILED]: __('Failed'),
  [TOOL_STALE]: s__('SecurityInventory|Stale'),
};
export const TOOL_STATUS_CONFIG = {
  [TOOL_ENABLED]: {
    name: 'check-circle-filled',
    variant: 'success',
    text: s__('SecurityInventory|Enabled'),
    fieldKey: 'success',
  },
  [TOOL_FAILED]: {
    name: 'status-failed',
    variant: 'danger',
    text: s__('SecurityInventory|Failed'),
    fieldKey: 'failure',
  },
  [TOOL_STALE]: {
    name: 'status-scheduled',
    variant: 'subtle',
    text: s__('SecurityInventory|Stale'),
    fieldKey: 'stale',
  },
  [TOOL_NOT_ENABLED]: {
    name: 'clear',
    variant: 'disabled',
    text: s__('SecurityInventory|Not enabled'),
    fieldKey: 'notConfigured',
  },
};

export const SEVERITY_FILTER_LABELS = {
  [CRITICAL]: s__('SecurityInventory|Severity critical'),
  [HIGH]: s__('SecurityInventory|Severity high'),
  [MEDIUM]: s__('SecurityInventory|Severity medium'),
  [LOW]: s__('SecurityInventory|Severity low'),
  [INFO]: s__('SecurityInventory|Severity info'),
  [UNKNOWN]: s__('SecurityInventory|Severity unknown'),
};
export const SEVERITY_SEGMENT_LABELS = {
  [CRITICAL]: s__('SecurityInventory|Vulnerability count critical'),
  [HIGH]: s__('SecurityInventory|Vulnerability count high'),
  [MEDIUM]: s__('SecurityInventory|Vulnerability count medium'),
  [LOW]: s__('SecurityInventory|Vulnerability count low'),
  [INFO]: s__('SecurityInventory|Vulnerability count info'),
  [UNKNOWN]: s__('SecurityInventory|Vulnerability count unknown'),
};
export const SEVERITY_FILTER_OPERATOR_TO_CONST = {
  [OPERATOR_LESS_THAN_OR_EQUAL]: 'LESS_THAN_OR_EQUAL_TO',
  [OPERATOR_IS]: 'EQUAL_TO',
  [OPERATOR_GREATER_THAN_OR_EQUAL]: 'GREATER_THAN_OR_EQUAL_TO',
};

export const STATUS_KEY = 'STATUS';
export const STATUS_NEEDS_ATTENTION = 'NEEDS_ATTENTION';
export const STATUS_STALE_SCANS = 'STALE_SCANS';
export const STATUS_UNPROTECTED = 'UNPROTECTED';
export const STATUS_FILTER_LABELS = {
  [STATUS_NEEDS_ATTENTION]: s__('SecurityInventory|Needs attention'),
  [STATUS_STALE_SCANS]: s__('SecurityInventory|Has stale scans'),
  [STATUS_UNPROTECTED]: s__('SecurityInventory|Unprotected'),
};
export const STATUS_FILTER_TO_VARIABLES = {
  [STATUS_NEEDS_ATTENTION]: { hasFailedOrWarning: true },
  [STATUS_STALE_SCANS]: { hasStale: true },
  [STATUS_UNPROTECTED]: { hasScanners: false },
};

export const MAX_SELECTED_COUNT = 100;

export const ACTION_TYPE_BULK_EDIT_SCANNERS = 'SCANNERS';
export const ACTION_TYPE_BULK_EDIT_ATTRIBUTES = 'ATTRIBUTES';
