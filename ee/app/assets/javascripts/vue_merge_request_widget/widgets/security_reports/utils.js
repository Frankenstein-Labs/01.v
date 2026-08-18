import { CRITICAL, HIGH } from 'ee/vulnerabilities/constants';
import { SECURITY_SCAN_TO_REPORT_TYPE } from '~/vue_merge_request_widget/constants';

export function highlightsFromReport(report, highlights = { [HIGH]: 0, [CRITICAL]: 0, other: 0 }) {
  // The data we receive from GraphQL is something like:
  // {
  //   full: { added: [{ severity: 'HIGH' ... }] },
  //   partial: { added: [{ severity: 'CRITICAL' ... }] }
  // }
  return [...(report.full?.added || []), ...(report.partial?.added || [])].reduce((acc, vuln) => {
    const severity = vuln.severity?.toLowerCase();
    if (severity === HIGH) {
      acc[HIGH] += 1;
    } else if (severity === CRITICAL) {
      acc[CRITICAL] += 1;
    } else {
      acc.other += 1;
    }
    return acc;
  }, highlights);
}

const getEnabledScanTypes = (scanData, scanMode) => {
  if (!scanData) return [];

  return Object.entries(scanData)
    .filter(
      ([scanType, isEnabled]) => isEnabled === true && scanType in SECURITY_SCAN_TO_REPORT_TYPE,
    )
    .map(([scanType]) => ({
      reportType: SECURITY_SCAN_TO_REPORT_TYPE[scanType],
      scanMode,
    }));
};

/**
 * Transforms GraphQL enabled security scans into report type configuration.
 * @param {Object} scans
 * @param {Object} scans.enabledSecurityScans
 * @returns {Array<{reportType: string, scanMode: string}>}
 * @example
 * const scans = {
 *   enabledSecurityScans: { sast: true, dast: false },
 *   enabledPartialSecurityScans: { sast: true, dast: false }
 * };
 * transformToEnabledScans(scans)
 * // Returns:
 * [
 *   { reportType: 'SAST', scanMode: 'FULL' },
 *   { reportType: 'SAST', scanMode: 'PARTIAL' },
 * ]
 */
export function transformToEnabledScans(scans) {
  return [
    ...getEnabledScanTypes(scans.enabledSecurityScans, 'FULL'),
    ...getEnabledScanTypes(scans.enabledPartialSecurityScans, 'PARTIAL'),
  ];
}

/**
 * Updates the state of a finding in the reports data by its UUID.
 * Used by the provider to mutate its own data when a consumer
 * requests a state change (e.g., dismissing a vulnerability).
 * @param {Object} reportsByScanType - The provider's report data, keyed by scan mode
 * @param {Object} reportsByScanType.full - Full scan reports keyed by report type
 * @param {Object} reportsByScanType.partial - Partial scan reports keyed by report type
 * @param {string} findingUuid - UUID of the finding to update
 * @param {string} newState - The new state (e.g., 'dismissed', 'detected')
 */
export function updateFindingState(reportsByScanType, findingUuid, newState) {
  ['full', 'partial'].forEach((scanModeKey) => {
    Object.values(reportsByScanType[scanModeKey]).forEach((report) => {
      const finding = report.findings?.find((f) => f.uuid === findingUuid);
      if (finding) {
        finding.state = newState;
      }
    });
  });
}
