import { isPlainObject } from 'lodash-es';
import { REPORT_TYPES_ALL } from 'ee/security_dashboard/constants';
import { convertObjectPropsToSnakeCase } from '~/lib/utils/common_utils';
import { __ } from '~/locale';

/**
 * Provided a security reports summary from the GraphQL API, this returns an array of arrays
 * representing a properly formatted report ready to be displayed in the UI. Each sub-array consists
 * of the user-friend report's name, and the summary's payload. Note that summary entries are
 * considered empty and are filtered out of the return if the payload is `null` or don't include
 * a vulnerabilitiesCount property. Report types whose name can't be matched to a user-friendly
 * name are filtered out as well.
 *
 * Take the following summary for example:
 * {
 *   containerScanning: { vulnerabilitiesCount: 123 },
 *   invalidReportType: { vulnerabilitiesCount: 123 },
 *   dast: null,
 * }
 *
 * The formatted summary would look like this:
 * [
 *   ['containerScanning', { vulnerabilitiesCount: 123 }]
 * ]
 *
 * Note that `invalidReportType` was filtered out as it can't be matched with a user-friendly name,
 * and the DAST report was omitted because it's empty (`null`).
 *
 * @param {Object} rawSummary
 * @returns {Array}
 */
export const getFormattedSummary = (rawSummary = {}) => {
  if (!isPlainObject(rawSummary)) {
    return [];
  }
  // Convert keys to snake case so they can be matched against REPORT_TYPES keys for translation
  const snakeCasedSummary = convertObjectPropsToSnakeCase(rawSummary);
  // Convert object to an array of entries to make it easier to loop through
  const summaryEntries = Object.entries(snakeCasedSummary);
  // Filter out empty entries as we don't want to display those in the summary
  const withoutEmptyEntries = summaryEntries.filter(
    ([, scanSummary]) => scanSummary?.vulnerabilitiesCount !== undefined,
  );
  // Replace keys with translations found in REPORT_TYPES if available
  const formattedEntries = withoutEmptyEntries.map(([scanType, scanSummary]) => {
    const name = REPORT_TYPES_ALL[scanType];
    return name ? [name, scanSummary] : null;
  });
  // Filter out keys that could not be matched with any translation and are thus considered invalid
  return formattedEntries.filter((entry) => entry !== null);
};

/**
 * Limits the number of projects displayed per vulnerability grade.
 *
 * Takes an array of vulnerability grade data and ensures that each grade
 * shows at most the specified number of projects. Grades with fewer projects
 * than the limit are returned unchanged.
 *
 * @param {Array} vulnerabilityGradesQueryResults - Array of vulnerability grade objects from GraphQL query
 * @param {number} [maxProjects=5] - Maximum number of projects to show per grade
 * @returns {Array} Array of vulnerability grade objects with limited project nodes
 */
export const limitVulnerabilityGradeProjects = (
  vulnerabilityGradesQueryResults,
  maxProjects = 5,
) => {
  return vulnerabilityGradesQueryResults.map((gradeData) => {
    const nodes = gradeData.projects?.nodes;

    if (!nodes || nodes.length <= maxProjects) {
      return gradeData;
    }

    return {
      ...gradeData,
      projects: {
        ...gradeData.projects,
        nodes: nodes.slice(0, maxProjects),
      },
    };
  });
};

export const PROJECT_LOADING_ERROR_MESSAGE = __('An error occurred while retrieving projects.');

/**
 * Custom error class for PDF export operations that are not ready.
 *
 * @param {string} message - User-friendly error message describing why the export isn't ready
 */
export class PdfExportError extends Error {
  constructor(message) {
    super(message);
    this.name = 'PdfExportError';
  }
}

export default () => ({});
