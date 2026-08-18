import { s__ } from '~/locale';
import { getCssVariable } from '~/lib/utils/css_utils';
import { getIdFromGraphQLId, isGid } from '~/graphql_shared/utils';
import { SEVERITY_LEVELS } from '../constants';

export const TAB_FILTERS = {
  OPERATIONAL: 'OPERATIONAL',
};

/**
 * Formats vulnerability data by severity for chart visualization
 *
 * @param {Array} vulnerabilitiesBySeries - Array of vulnerability data nodes
 * @param {boolean} isStacked - Whether to format for stacked column chart (true) or line chart (false)
 * @returns {Array} Formatted chart series data for severity grouping
 *
 * @note
 * The `id`-property is used to construct the link to the vulnerability report page
 * and must match the filter value that is expected in the vulnerability report page
 * see `constructVulnerabilitiesReportWithFiltersPath` for more details
 */
const formatVulnerabilitiesBySeverity = (vulnerabilitiesBySeries, isStacked = false) => {
  const chartSeriesDataBySeverity = {
    CRITICAL: { name: SEVERITY_LEVELS.critical, id: 'CRITICAL', data: [] },
    HIGH: { name: SEVERITY_LEVELS.high, id: 'HIGH', data: [] },
    MEDIUM: { name: SEVERITY_LEVELS.medium, id: 'MEDIUM', data: [] },
    LOW: { name: SEVERITY_LEVELS.low, id: 'LOW', data: [] },
    INFO: { name: SEVERITY_LEVELS.info, id: 'INFO', data: [] },
    UNKNOWN: { name: SEVERITY_LEVELS.unknown, id: 'UNKNOWN', data: [] },
  };

  vulnerabilitiesBySeries.forEach((node) => {
    const { date, bySeverity = [] } = node;
    bySeverity.forEach(({ severity, count }) => {
      if (chartSeriesDataBySeverity[severity]) {
        // Line chart expects [x, y] tuples, stacked chart expects y values only
        chartSeriesDataBySeverity[severity].data.push(isStacked ? count : [date, count]);
      }
    });
  });

  return Object.values(chartSeriesDataBySeverity).filter((item) => item.data.length > 0);
};

/**
 * Formats vulnerability data by report type for chart visualization
 *
 * @param {Array} vulnerabilitiesBySeries - Array of vulnerability data nodes
 * @param {boolean} isStacked - Whether to format for stacked column chart (true) or line chart (false)
 * @returns {Array} Formatted chart series data for report type grouping
 *
 * @note
 * The `id`-property is used to construct the link to the vulnerability report page
 * and must match the filter value that is expected in the vulnerability report page
 * see `constructVulnerabilitiesReportWithFiltersPath` for more details
 */
const formatVulnerabilitiesByReportType = (vulnerabilitiesBySeries, isStacked = false) => {
  const chartSeriesDataByReportType = {
    SAST: { name: s__('reportType|SAST'), id: 'SAST', data: [] },
    DEPENDENCY_SCANNING: {
      name: s__('reportType|Dependency Scanning'),
      id: 'DEPENDENCY_SCANNING',
      data: [],
    },
    CONTAINER_SCANNING: {
      name: s__('reportType|Container Scanning'),
      id: 'CONTAINER_SCANNING',
      data: [],
    },
    DAST: { name: s__('reportType|DAST'), id: 'DAST', data: [] },
    SECRET_DETECTION: {
      name: s__('reportType|Secret Detection'),
      id: 'SECRET_DETECTION',
      data: [],
    },
    COVERAGE_FUZZING: {
      name: s__('reportType|Coverage Fuzzing'),
      id: 'COVERAGE_FUZZING',
      data: [],
    },
    API_FUZZING: { name: s__('reportType|API Fuzzing'), id: 'API_FUZZING', data: [] },
    CLUSTER_IMAGE_SCANNING: {
      name: s__('reportType|Cluster Image Scanning'),
      id: 'CLUSTER_IMAGE_SCANNING',
      data: [],
    },
    CONTAINER_SCANNING_FOR_REGISTRY: {
      name: s__('reportType|Container Scanning for Registry'),
      id: 'CONTAINER_SCANNING_FOR_REGISTRY',
      data: [],
    },
    GENERIC: { name: s__('reportType|Manually added'), id: 'GENERIC', data: [] },
  };

  vulnerabilitiesBySeries.forEach((node) => {
    const { date, byReportType = [] } = node;
    byReportType.forEach(({ reportType, count }) => {
      if (chartSeriesDataByReportType[reportType]) {
        // Line chart expects [x, y] tuples, stacked chart expects y values only
        chartSeriesDataByReportType[reportType].data.push(isStacked ? count : [date, count]);
      }
    });
  });

  return Object.values(chartSeriesDataByReportType).filter((item) => item.data.length > 0);
};

/**
 * Formats vulnerability data for chart visualization
 *
 * @param {Array} vulnerabilitiesBySeries - Array of vulnerability data nodes
 *   Each node should have the structure:
 *   {
 *     date?: string,   // Timestamp when grouped by date (trend chart)
 *     name?: string,   // Label when grouped by age bucket (e.g., "0-30 days")
 *     bySeverity: Array<{ severity: string, count: number }>,
 *     byReportType: Array<{ reportType: string, count: number }>
 *   }
 *
 * @param {Object} options - Formatting options
 * @param {string} options.groupBy - The grouping to use for the chart ('severity' or 'reportType')
 * @param {boolean} options.isStacked - Whether to format for stacked column chart (true) or line chart (false)
 *
 * @returns {Array} Formatted chart series data
 *   For line chart: [
 *     { name: 'Critical', id: 'CRITICAL', data: [[timestamp1, count1], [timestamp2, count2], ...] },
 *     ...
 *   ]
 *   For stacked chart: [
 *     { name: 'Critical', id: 'CRITICAL', data: [count1, count2, ...] },
 *     ...
 *   ]
 */
export const formatVulnerabilitiesBySeries = (
  vulnerabilitiesBySeries,
  { groupBy = 'severity', isStacked = false } = {},
) => {
  if (!Array.isArray(vulnerabilitiesBySeries) || vulnerabilitiesBySeries.length === 0) {
    return [];
  }

  if (groupBy === 'severity') {
    return formatVulnerabilitiesBySeverity(vulnerabilitiesBySeries, isStacked);
  }
  return formatVulnerabilitiesByReportType(vulnerabilitiesBySeries, isStacked);
};

/**
 * Constructs a link for the chart tooltip based on the series ID and group by
 *
 * @param {string} securityVulnerabilitiesPath - The path to the security vulnerabilities page
 * @param {string} seriesId - The ID of the series
 * @param {string} filterKey - The primary filter key (usually the groupedBy value)
 * @param {Object} additionalFilters - Additional filters to include in the URL
 *
 * @note
 * This is a temporary solution until the link is provided by the GraphQL API
 * See https://gitlab.com/gitlab-org/gitlab/-/issues/559212 for more details
 */
export const constructVulnerabilitiesReportWithFiltersPath = ({
  securityVulnerabilitiesPath,
  seriesId,
  filterKey,
  additionalFilters = {},
}) => {
  const SPECIAL_LINK_CASES = {
    CLUSTER_IMAGE_SCANNING: {
      // Cluster image scanning is a special case because it has a different tab in the vulnerability report page
      tab: TAB_FILTERS.OPERATIONAL,
    },
  };

  const params = new URLSearchParams();

  const specialCase = SPECIAL_LINK_CASES[seriesId];
  if (specialCase) {
    Object.entries(specialCase).forEach(([key, value]) => {
      params.set(key, value);
    });
  } else {
    params.set(filterKey, seriesId);
  }

  const UNSUPPORTED_FILTERS = new Set(['securityAttributesFilters']);
  // The Vulnerability Report expects numeric IDs
  const stripGid = (v) => (isGid(v) ? getIdFromGraphQLId(v) : v);

  Object.entries(additionalFilters)
    .filter(
      ([key, value]) => key !== filterKey && !UNSUPPORTED_FILTERS.has(key) && value?.length > 0,
    )
    .forEach(([key, value]) => {
      const values = Array.isArray(value) ? value : [value];
      // A filter can have multiple values (e.g. severity=HIGH,MEDIUM) so we need to join them with commas
      params.set(key, values.map(stripGid).join(','));
    });

  return `${securityVulnerabilitiesPath}?${params.toString()}`;
};

const OPTIMAL_ASPECT_RATIO = 4 / 3;

/**
 * Generates an optimal grid layout for a given number of items within a container.
 *
 * The algorithm finds the best row/column configuration by minimizing a score that
 * balances two factors:
 * 1. Aspect ratio - How close each tile's aspect ratio is to the optimal (4:3)
 * 2. Space utilization - How efficiently the grid uses available space (weighted 2x)
 *
 * @param {Object} params - The configuration parameters
 * @param {number} params.totalItems - The number of items to place in the grid (must be > 0)
 * @param {number} params.width - The container width in pixels
 * @param {number} params.height - The container height in pixels
 *
 * @returns {Object|null} The optimal grid configuration or null if n <= 0
 * @returns {number} returns.rows - The optimal number of rows
 * @returns {number} returns.cols - The optimal number of columns
 *
 * @example
 * // Returns { rows: 4, cols: 6 } for 24 items in a 800x600 container
 * const grid = generateGrid({ totalItems: 24, width: 800, height: 600 });
 *
 * @example
 * // Returns { rows: 3, cols: 3 } for 9 items in a square container
 * const grid = generateGrid({ totalItems: 9, width: 400, height: 400 });
 *
 * @example
 * // Returns { rows: 10, cols: 10 } for 96 items in a 600x450 container
 * const grid = generateGrid({ totalItems: 0, width: 600, height: 450 }); // null
 */
export const generateGrid = ({ totalItems, width, height }) => {
  if (totalItems <= 0) return null;

  let bestGrid = null;
  let bestScore = Infinity;

  // Limit search space for columns and rows with logical options – close to square with buffer (+ 2)
  const maxDim = Math.ceil(Math.sqrt(totalItems)) + 2;

  for (let rows = 1; rows <= maxDim; rows += 1) {
    for (let cols = 1; cols <= maxDim; cols += 1) {
      if (rows * cols >= totalItems) {
        const rectWidth = width / cols;
        const rectHeight = height / rows;
        const aspectRatio = rectWidth / rectHeight;
        const utilization = totalItems / (rows * cols);

        const score = Math.abs(aspectRatio - OPTIMAL_ASPECT_RATIO) + 2 * (1 - utilization);

        if (score < bestScore) {
          bestScore = score;
          bestGrid = { rows, cols };
        }
      }
    }
  }

  return bestGrid;
};

/**
 * Gets the computed hex color for each severity level from their CSS custom property
 * @returns {Object} keys are severities and values are their hex colors
 */
export const getSeverityColors = () => {
  return Object.fromEntries(
    Object.keys(SEVERITY_LEVELS).map((severity) => [
      severity,
      getCssVariable(`--severity-color-${severity}`),
    ]),
  );
};
