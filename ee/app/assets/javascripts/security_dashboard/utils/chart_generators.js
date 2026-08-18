import { markRaw } from 'vue';
import VulnerabilitiesForSeverityWrapper from '../components/shared/vulnerabilities_for_severity_wrapper.vue';
import { SEVERITY_LEVELS_KEYS } from '../constants';

const DEFAULT_PANEL_WIDTH = 2;
const DEFAULT_PANEL_HEIGHT = 1;

/**
 * Generates configuration objects for vulnerability count per severity panels.
 *
 * Creates a horizontally-aligned row of panels, one for each severity level,
 * with each panel positioned sequentially from left to right.
 *
 * @param {Object} options - Configuration options
 * @param {Object} options.namespace - Namespace to be used for the panel
 * @param {Object} options.filters - GraphQL query filters
 * @returns {Array<Object>} Array of panel configuration objects
 */
export const generateVulnerabilitiesForSeverityPanels = ({ namespace, filters }) => {
  return SEVERITY_LEVELS_KEYS.map((severity, index) => ({
    id: severity,
    component: markRaw(VulnerabilitiesForSeverityWrapper),
    componentProps: {
      namespace,
      severity,
      filters,
    },
    gridAttributes: {
      width: DEFAULT_PANEL_WIDTH,
      height: DEFAULT_PANEL_HEIGHT,
      yPos: 0,
      xPos: DEFAULT_PANEL_WIDTH * index,
    },
  }));
};
