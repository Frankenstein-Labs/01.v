import { s__, __ } from '~/locale';
import vulnerabilityStateMutations from 'ee/security_dashboard/graphql/mutate_vulnerability_state';
import dismissFindingMutation from 'ee/security_dashboard/graphql/mutations/dismiss_finding.mutation.graphql';
import revertFindingToDetectedMutation from 'ee/security_dashboard/graphql/mutations/revert_finding_to_detected.mutation.graphql';

import {
  FEEDBACK_TYPE_ISSUE,
  FEEDBACK_TYPE_MERGE_REQUEST,
} from '~/vue_shared/security_reports/constants';

/**
 * Vulnerability severities as provided by the backend on vulnerability
 * objects.
 */
export const CRITICAL = 'critical';
export const HIGH = 'high';
export const MEDIUM = 'medium';
export const LOW = 'low';
export const INFO = 'info';
export const UNKNOWN = 'unknown';

/**
 * All vulnerability severities in decreasing order.
 */
export const SEVERITIES = [CRITICAL, HIGH, MEDIUM, LOW, INFO, UNKNOWN];

export const SEVERITY_COUNT_LIMIT = 1000;

const falsePositiveMessage = s__('VulnerabilityManagement|Will not fix or a false-positive');

export const DISMISSAL_REASONS = {
  acceptable_risk: s__('VulnerabilityDismissalReasons|Acceptable risk'),
  false_positive: s__('VulnerabilityDismissalReasons|False positive'),
  mitigating_control: s__('VulnerabilityDismissalReasons|Mitigating control'),
  used_in_tests: s__('VulnerabilityDismissalReasons|Used in tests'),
  not_applicable: s__('VulnerabilityDismissalReasons|Not applicable'),
};

// Long-form descriptions for each dismissal reason. These mirror
// `Vulnerabilities::DismissalReasonEnum.translated_descriptions` on the backend
// and reuse the same shared `.po` catalog entries, so the page no longer needs
// them injected from the HAML payload.
export const DISMISSAL_REASON_DESCRIPTIONS = {
  acceptable_risk: __(
    'The vulnerability is known, and has not been remediated or mitigated, but is considered to be an acceptable business risk.',
  ),
  false_positive: __(
    'An error in reporting in which a test result incorrectly indicates the presence of a vulnerability in a system when the vulnerability is not present.',
  ),
  mitigating_control: __(
    'A management, operational, or technical control (that is, safeguard or countermeasure) employed by an organization that provides equivalent or comparable protection for an information system.',
  ),
  used_in_tests: __(
    'The finding is not a vulnerability because it is part of a test or is test data.',
  ),
  not_applicable: __(
    'The vulnerability is known, and has not been remediated or mitigated, but is considered to be in a part of the application that will not be updated.',
  ),
};

export const VULNERABILITY_STATES = {
  detected: s__('VulnerabilityStatusTypes|Needs triage'),
  confirmed: s__('VulnerabilityStatusTypes|Confirmed'),
  dismissed: s__('VulnerabilityStatusTypes|Dismissed'),
  resolved: s__('VulnerabilityStatusTypes|Resolved'),
};

export const VULNERABILITY_STATE_OBJECTS = {
  detected: {
    action: 'revert',
    state: 'detected',
    searchParamValue: 'DETECTED',
    buttonText: VULNERABILITY_STATES.detected,
    dropdownText: s__('VulnerabilityStatusTypes|Needs triage'),
    dropdownDescription: s__('VulnerabilityManagement|Requires assessment'),
    description: s__('VulnerabilityManagement|An unverified non-confirmed finding'),
    mutation: vulnerabilityStateMutations.revert,
    findingMutation: revertFindingToDetectedMutation,
  },
  confirmed: {
    action: 'confirm',
    state: 'confirmed',
    searchParamValue: 'CONFIRMED',
    buttonText: VULNERABILITY_STATES.confirmed,
    dropdownText: s__('VulnerabilityStatusTypes|Confirmed'),
    dropdownDescription: s__('VulnerabilityManagement|A true-positive and will fix'),
    description: s__('VulnerabilityManagement|A verified true-positive vulnerability'),
    mutation: vulnerabilityStateMutations.confirm,
  },
  dismissed: {
    action: 'dismiss',
    state: 'dismissed',
    searchParamValue: 'DISMISSED',
    buttonText: VULNERABILITY_STATES.dismissed,
    dropdownText: s__('VulnerabilityStatusTypes|Dismissed'),
    dropdownDescription: falsePositiveMessage,
    mutation: vulnerabilityStateMutations.dismiss,
    findingMutation: dismissFindingMutation,
  },
  resolved: {
    action: 'resolve',
    state: 'resolved',
    searchParamValue: 'RESOLVED',
    buttonText: VULNERABILITY_STATES.resolved,
    dropdownText: s__('VulnerabilityStatusTypes|Resolved'),
    dropdownDescription: s__('VulnerabilityManagement|Verified as fixed or mitigated'),
    description: s__('VulnerabilityManagement|A removed or remediated vulnerability'),
    mutation: vulnerabilityStateMutations.resolve,
  },
};

export const FEEDBACK_TYPES = {
  ISSUE: FEEDBACK_TYPE_ISSUE,
  MERGE_REQUEST: FEEDBACK_TYPE_MERGE_REQUEST,
};

export const RELATED_ISSUES_ERRORS = {
  LINK_ERROR: s__('VulnerabilityManagement|Could not process %{issueReference}: %{errorMessage}.'),
  UNLINK_ERROR: s__(
    'VulnerabilityManagement|Something went wrong while trying to unlink the issue. Please try again later.',
  ),
  ISSUE_ID_ERROR: s__('VulnerabilityManagement|invalid issue link or ID'),
};

export const REGEXES = {
  ISSUE_FORMAT: /^#?(\d+)$/, // Matches '123' and '#123'.
  LINK_FORMAT: /\/(.+\/.+)\/-\/issues\/(\d+)/, // Matches '/username/project/-/issues/123'.
};

export const SUPPORTING_MESSAGE_TYPES = {
  // eslint-disable-next-line @gitlab/require-i18n-strings
  RECORDED: 'Recorded',
};

export const SUPPORTED_IDENTIFIER_TYPE_CWE = 'cwe';
export const SUPPORTED_IDENTIFIER_TYPE_OWASP = 'owasp';

export const VULNERABILITY_TRAINING_HEADING = {
  title: s__('Vulnerability|Training'),
};

export const SECURITY_TRAINING_URL_STATUS_COMPLETED = 'COMPLETED';
export const SECURITY_TRAINING_URL_STATUS_PENDING = 'PENDING';

export const CREATE_MR_ACTION = {
  name: s__('ciReport|Resolve with merge request'),
  tagline: s__('ciReport|Automatically apply the patch in a new branch'),
  action: 'create-merge-request',
};

export const DOWNLOAD_PATCH_ACTION = {
  name: s__('ciReport|Download patch to resolve'),
  tagline: s__('ciReport|Download the patch to apply it manually'),
  action: 'download-patch',
};

export const CODE_FLOW_TAB_URL = 'code_flow';
export const DETAIL_TAB_URL = 'details';

export const VULNERABILITY_TAB_NAMES = Object.freeze({
  DETAILS: s__('Vulnerability|Details'),
  CODE_FLOW: s__('Vulnerability|Code flow'),
});

export const VULNERABILITY_TAB_INDEX_TO_NAME = {
  1: CODE_FLOW_TAB_URL,
};

export const CONFIDENCE_SCORES = {
  MINIMAL: 0.6,
  LIKELY_FALSE_POSITIVE: 0.8,
};

export const FP_CONFIDENCE_LABELS = {
  high: s__('Vulnerability|High'),
  medium: s__('Vulnerability|Medium'),
  low: s__('Vulnerability|Low'),
  none: s__('Vulnerability|None'),
};

export const FP_CONFIDENCE_TEXT_CLASSES = {
  high: 'gl-text-success',
  medium: 'gl-text-warning',
  low: 'gl-text-danger',
  none: 'gl-text-subtle',
};

export const FLAG_STATUSES = {
  NOT_STARTED: 'NOT_STARTED',
  IN_PROGRESS: 'IN_PROGRESS',
  DETECTED_AS_FP: 'DETECTED_AS_FP',
  DETECTED_AS_NOT_FP: 'DETECTED_AS_NOT_FP',
  FAILED: 'FAILED',
  DISMISSED: 'DISMISSED',
};

export const COMPLETED_DETECTION_STATUSES = [
  FLAG_STATUSES.DETECTED_AS_FP,
  FLAG_STATUSES.DETECTED_AS_NOT_FP,
];

export const PENDING_DETECTION_STATUSES = [FLAG_STATUSES.NOT_STARTED, FLAG_STATUSES.IN_PROGRESS];

export const MANUAL_ORIGIN_PREFIX = 'manual_';

// Mirrors `Vulnerabilities::Flag::AI_MANAGED_ORIGINS` on the backend.
export const AI_MANAGED_ORIGINS = ['ai_sast_fp_detection', 'ai_secret_detection_fp_detection'];
