import { sprintf, s__, n__ } from '~/locale';
import { EXTENSION_ICONS } from '~/vue_merge_request_widget/constants';
import { LICENSE_APPROVAL_STATUS } from 'ee/vue_shared/license_compliance/constants';

const APPROVAL_STATUS_TO_ICON = {
  allowed: EXTENSION_ICONS.success,
  denied: EXTENSION_ICONS.failed,
  unclassified: EXTENSION_ICONS.notice,
};

export const parseDependencies = (dependencies) => {
  return dependencies
    .map((dependency) => {
      return dependency.name;
    })
    .join(', ');
};

/**
 * Returns the appropriate summary text based on license compliance report state.
 * @param {Object} params - Parameters for determining summary text
 * @param {boolean} params.hasBaseReportLicenses - Whether base report has existing licenses
 * @param {boolean} params.hasDeniedLicense - Whether there are denied licenses
 * @param {boolean} params.hasApprovalRequired - Whether approval is required
 * @param {number} params.licenseReportCount - Number of licenses detected
 * @returns {string} Localized summary text for the license compliance widget
 */
export const getSummaryTextWithReportItems = ({
  hasBaseReportLicenses,
  hasDeniedLicense,
  hasApprovalRequired,
  licenseReportCount,
}) => {
  const hasNew = hasBaseReportLicenses;
  const hasViolation = hasDeniedLicense;
  const needsApproval = hasApprovalRequired && hasViolation;

  if (needsApproval && hasNew) {
    return n__(
      'LicenseCompliance|License compliance detected %d new license and policy violation; approval required',
      'LicenseCompliance|License compliance detected %d new licenses and policy violations; approval required',
      licenseReportCount,
    );
  }

  if (needsApproval) {
    return n__(
      'LicenseCompliance|License compliance detected %d license and policy violation for the source branch only; approval required',
      'LicenseCompliance|License compliance detected %d licenses and policy violations for the source branch only; approval required',
      licenseReportCount,
    );
  }

  if (hasViolation && hasNew) {
    return n__(
      'LicenseCompliance|License compliance detected %d new license and policy violation',
      'LicenseCompliance|License compliance detected %d new licenses and policy violations',
      licenseReportCount,
    );
  }

  if (hasViolation) {
    return n__(
      'LicenseCompliance|License compliance detected %d license and policy violation for the source branch only',
      'LicenseCompliance|License compliance detected %d licenses and policy violations for the source branch only',
      licenseReportCount,
    );
  }

  if (hasNew) {
    return n__(
      'LicenseCompliance|License compliance detected %d new license',
      'LicenseCompliance|License compliance detected %d new licenses',
      licenseReportCount,
    );
  }

  return n__(
    'LicenseCompliance|License compliance detected %d license for the source branch only',
    'LicenseCompliance|License compliance detected %d licenses for the source branch only',
    licenseReportCount,
  );
};

/**
 * Transforms a raw license object from the API into a format suitable for the MR widget.
 * Output is used by groupLicensesByStatus.
 * @param {Object} license - Raw license object from the license_scanning_reports API
 * @param {string} fullReportPath - Path to the full license report
 * @returns {Object} Transformed license object with status, icon, link, supportingText, and actions
 * @example
 * const license = {
 *   name: 'MIT License',
 *   url: 'https://spdx.org/licenses/MIT.html',
 *   dependencies: [{ name: 'lodash' }],
 *   classification: { approval_status: 'unclassified' },
 * };
 * transformLicense(license, '/project/-/licenses');
 * // Returns: { status: 'unclassified', icon: {...}, link: {...}, actions: [...] }
 */
export const transformLicense = (license, fullReportPath) => {
  const { approval_status: approvalStatus } = license.classification;
  let supportingText;
  let actions;

  if (
    approvalStatus === LICENSE_APPROVAL_STATUS.ALLOWED ||
    approvalStatus === LICENSE_APPROVAL_STATUS.UNCLASSIFIED
  ) {
    actions = [
      {
        text: n__('Used by %d package', 'Used by %d packages', license.dependencies.length),
        href: fullReportPath,
      },
    ];
  } else {
    supportingText =
      license.dependencies.length > 0
        ? sprintf(s__('License Compliance| Used by %{dependencies}'), {
            dependencies: parseDependencies(license.dependencies),
          })
        : '';
  }

  return {
    status: approvalStatus,
    icon: {
      name: APPROVAL_STATUS_TO_ICON[approvalStatus],
    },
    link: {
      href: license.url,
      text: license.name,
    },
    supportingText,
    actions,
  };
};

/**
 * Groups an array of transformed licenses by their status property.
 * Takes output from transformLicense. Output is used by createLicenseSections.
 * @param {Array<{status: string}>} licenses - Array of transformed license objects from transformLicense
 * @returns {Object} Object with status values as keys and arrays of licenses as values
 * @example
 * const licenses = [
 *   { status: 'unclassified', link: { text: 'LGPL-2.1' } },
 *   { status: 'denied', link: { text: 'GPL-3.0' } },
 * ];
 * groupLicensesByStatus(licenses);
 * // Returns: { unclassified: [...], denied: [...] }
 */
export const groupLicensesByStatus = (licenses) => {
  return licenses.reduce(
    (acc, license) => ({
      ...acc,
      [license.status]: [...(acc[license.status] || []), license],
    }),
    {},
  );
};

/**
 * Creates license sections from grouped licenses for display in the MR widget.
 * Sections are ordered: denied, unclassified, allowed. Empty groups are excluded.
 * Takes output from groupLicensesByStatus.
 * @param {Object} groupedLicenses - Object from groupLicensesByStatus with status keys and arrays of licenses
 * @returns {Array<{header: string, text: string, children: Array}>} Array of section objects
 * @example
 * const groupedLicenses = {
 *   denied: [{ status: 'denied', link: { text: 'GPL-3.0' } }],
 *   unclassified: [{ status: 'unclassified', link: { text: 'LGPL-2.1' } }],
 * };
 * createLicenseSections(groupedLicenses);
 * // Returns: [{ header: 'Denied', text: '...', children: [...] }, { header: 'Uncategorized', ... }]
 */
export const createLicenseSections = (groupedLicenses) => {
  const sections = [];

  if (groupedLicenses.denied?.length > 0) {
    sections.push({
      header: s__('LicenseCompliance|Denied'),
      text: s__(
        "LicenseCompliance|Out-of-compliance with the project's policies and should be removed",
      ),
      children: groupedLicenses.denied,
    });
  }

  if (groupedLicenses.unclassified?.length > 0) {
    sections.push({
      header: s__('LicenseCompliance|Uncategorized'),
      text: s__('LicenseCompliance|No policy matches this license'),
      children: groupedLicenses.unclassified,
    });
  }

  if (groupedLicenses.allowed?.length > 0) {
    sections.push({
      header: s__('LicenseCompliance|Allowed'),
      text: s__('LicenseCompliance|Acceptable for use in this project'),
      children: groupedLicenses.allowed,
    });
  }

  return sections;
};
