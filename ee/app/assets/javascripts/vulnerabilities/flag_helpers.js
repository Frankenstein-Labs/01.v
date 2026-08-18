import {
  SECURITY_REPORT_TYPE_ENUM_DEPENDENCY_SCANNING,
  SECURITY_REPORT_TYPE_ENUM_SAST,
} from '~/vue_shared/security_reports/constants';
import {
  FLAG_STATUSES,
  COMPLETED_DETECTION_STATUSES,
  PENDING_DETECTION_STATUSES,
  MANUAL_ORIGIN_PREFIX,
  AI_MANAGED_ORIGINS,
  CONFIDENCE_SCORES,
  FP_CONFIDENCE_LABELS,
  FP_CONFIDENCE_TEXT_CLASSES,
} from './constants';

export const isManualFlag = (flag) => Boolean(flag?.origin?.startsWith(MANUAL_ORIGIN_PREFIX));
export const isManagedAiFlag = (flag) => AI_MANAGED_ORIGINS.includes(flag?.origin);

// A high false-positive confidence means the finding is likely NOT a real vulnerability.
export const fpConfidenceLevel = (score) => {
  const value = score ?? 0;

  if (value >= CONFIDENCE_SCORES.LIKELY_FALSE_POSITIVE) return 'high';
  if (value > CONFIDENCE_SCORES.MINIMAL) return 'medium';
  if (value >= 0.01) return 'low';

  return 'none';
};

// Shared by the Risk panel row and the AI false-positive analysis drawer so they
// always render the same label/color for a given flag.
export const fpConfidenceLabel = (flag) =>
  FP_CONFIDENCE_LABELS[fpConfidenceLevel(flag?.confidenceScore)];

export const fpConfidenceTextClass = (flag) =>
  FP_CONFIDENCE_TEXT_CLASSES[fpConfidenceLevel(flag?.confidenceScore)];

export const isScannerFp = (flag) => !isManagedAiFlag(flag) && !isManualFlag(flag);

export const hasActiveAiFpDetection = (flag) =>
  Boolean(flag?.status) && flag.status !== FLAG_STATUSES.DISMISSED && isManagedAiFlag(flag);

export const isAiDetectedAsFalsePositive = (flag) =>
  flag?.status === FLAG_STATUSES.DETECTED_AS_FP && isManagedAiFlag(flag);

export const isPendingFpDetection = (flag) => PENDING_DETECTION_STATUSES.includes(flag?.status);

export const isFailedFpDetection = (flag) => flag?.status === FLAG_STATUSES.FAILED;

export const isCompletedFpDetection = (flag) => COMPLETED_DETECTION_STATUSES.includes(flag?.status);

/**
 * Whether Agentic SAST Vulnerability Resolution applies to a vulnerability.
 *
 * @see https://docs.gitlab.com/user/application_security/vulnerabilities/agentic_vulnerability_resolution/#automatic-resolution-conditions
 * @param {Object} options
 * @param {Object} options.vulnerability - The vulnerability, with `aiResolutionAvailable`, `duoSastVrWorkflowEnabled`, and `latestFlag`.
 * @param {boolean} options.duoAgentPlatformAvailable - Whether the Duo Agent Platform is available.
 * @param {boolean} options.agenticSastVrUi - Whether the `agentic_sast_vr_ui` feature flag is enabled.
 * @returns {boolean} `true` when all conditions for SAST VR are met.
 */
export const isSastVrApplicable = ({ vulnerability, duoAgentPlatformAvailable, agenticSastVrUi }) =>
  Boolean(
    agenticSastVrUi &&
    duoAgentPlatformAvailable &&
    vulnerability?.aiResolutionAvailable &&
    vulnerability?.duoSastVrWorkflowEnabled &&
    !isAiDetectedAsFalsePositive(vulnerability?.latestFlag),
  );

/**
 * Filters a list of vulnerabilities to those eligible for Agentic SAST VR.
 *
 * @param {Object[]} vulnerabilities - The vulnerabilities to filter.
 * @param {Object} options
 * @param {boolean} options.duoAgentPlatformAvailable - Whether the Duo Agent Platform is available.
 * @param {boolean} options.agenticSastVrUi - Whether the `agentic_sast_vr_ui` feature flag is enabled.
 * @returns {Object[]} The eligible vulnerabilities.
 */
export const eligibleSastVrVulnerabilities = (
  vulnerabilities,
  { duoAgentPlatformAvailable, agenticSastVrUi },
) =>
  vulnerabilities.filter((vulnerability) =>
    isSastVrApplicable({ vulnerability, duoAgentPlatformAvailable, agenticSastVrUi }),
  );

/**
 * Whether Agentic SAST false-positive detection can be triggered for a vulnerability.
 *
 * Severity is deliberately not checked. The bulk API takes severity from the caller, so
 * filtering to high and critical here would silently drop findings the backend accepts.
 * The automatic trigger keeps its own high_or_critical_severity? guard.
 *
 * @param {Object} options
 * @param {Object} options.vulnerability - The vulnerability, with `reportType` and `latestFlag`.
 * @param {boolean} options.duoAgentPlatformAvailable - Whether the Duo Agent Platform is available.
 * @param {boolean} options.duoSastFpDetectionEnabled - Whether FP detection is enabled for the project.
 * @returns {boolean} `true` when all conditions for SAST FP detection are met.
 */
export const isSastFpDetectionApplicable = ({
  vulnerability,
  duoAgentPlatformAvailable,
  duoSastFpDetectionEnabled,
}) =>
  Boolean(
    duoAgentPlatformAvailable &&
    duoSastFpDetectionEnabled &&
    vulnerability?.reportType === SECURITY_REPORT_TYPE_ENUM_SAST &&
    !hasActiveAiFpDetection(vulnerability?.latestFlag),
  );

/**
 * Filters a list of vulnerabilities to those eligible for SAST FP detection.
 *
 * @param {Object[]} vulnerabilities - The vulnerabilities to filter.
 * @param {Object} options
 * @param {boolean} options.duoAgentPlatformAvailable - Whether the Duo Agent Platform is available.
 * @param {boolean} options.duoSastFpDetectionEnabled - Whether FP detection is enabled for the project.
 * @returns {Object[]} The eligible vulnerabilities.
 */
export const eligibleSastFpVulnerabilities = (
  vulnerabilities,
  { duoAgentPlatformAvailable, duoSastFpDetectionEnabled },
) =>
  vulnerabilities.filter((vulnerability) =>
    isSastFpDetectionApplicable({
      vulnerability,
      duoAgentPlatformAvailable,
      duoSastFpDetectionEnabled,
    }),
  );

/**
 * Whether the single-vulnerability SCA Vulnerability Resolution action applies.
 *
 * There is no precomputed "fix available" signal for SCA, so eligibility here is
 * just "a supported SCA row": the fix-availability check happens server-side when
 * the action is triggered (check-on-click).
 *
 * @param {Object} options
 * @param {Object} options.vulnerability - The vulnerability, with `reportType`.
 * @param {boolean} options.securityRemediationProfiles - Whether the `security_remediation_profiles` feature flag is enabled.
 * @returns {boolean} `true` when the SCA VR action should be offered.
 */
export const isScaVrApplicable = ({ vulnerability, securityRemediationProfiles }) =>
  Boolean(
    securityRemediationProfiles &&
    vulnerability?.reportType === SECURITY_REPORT_TYPE_ENUM_DEPENDENCY_SCANNING,
  );
