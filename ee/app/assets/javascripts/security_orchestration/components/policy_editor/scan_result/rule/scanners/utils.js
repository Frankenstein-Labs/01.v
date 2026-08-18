import { xor, omit } from 'lodash-es';
import {
  ANY_OPERATOR,
  GREATER_THAN_OPERATOR,
  BRANCH_EXCEPTIONS_KEY,
} from 'ee/security_orchestration/components/policy_editor/constants';
import { DEFAULT_EPSS_VALUE } from 'ee/security_orchestration/components/policy_editor/scan_result/lib/rules';
import {
  AGE,
  AGE_TOOLTIP_NO_PREVIOUSLY_EXISTING_VULNERABILITY,
  AGE_TOOLTIP_MAXIMUM_REACHED,
  ATTRIBUTE,
  DEFAULT_VULNERABILITY_STATES,
  NEWLY_DETECTED,
  PREVIOUSLY_EXISTING,
  FIX_AVAILABLE,
  FALSE_POSITIVE,
  STATUS,
  KNOWN_EXPLOITED,
  EPSS_SCORE,
  ENRICHMENT_DATA_UNAVAILABLE,
} from 'ee/security_orchestration/components/policy_editor/scan_result/rule/scan_filters/constants';

/**
 * flatten groups of states to a single array
 * @param vulnerabilityStates
 * @returns {*[]|null}
 */
export function normalizeVulnerabilityStates(vulnerabilityStates) {
  const states = [
    ...(vulnerabilityStates[NEWLY_DETECTED] || []),
    ...(vulnerabilityStates[PREVIOUSLY_EXISTING] || []),
  ];

  if (!states.length) return null;

  const matchesDefault = xor(states, DEFAULT_VULNERABILITY_STATES).length === 0;

  return matchesDefault ? [] : states;
}

/**
 * used for adding new status filter
 * additionally to existing ones
 * @param filters
 * @returns {*&{[p: number]: boolean}}
 */
export function enableStatusFilter(filters) {
  const nextKey = filters[NEWLY_DETECTED] ? PREVIOUSLY_EXISTING : NEWLY_DETECTED;

  return {
    ...filters,
    [nextKey]: true,
  };
}

/**
 * Enable attribute filter based on selected attributes
 * @param attributes
 * @returns {*&{[p: number]: boolean}}
 */
export function enableAttributeFilter(attributes) {
  const key = Object.keys(attributes)[0] === FIX_AVAILABLE ? FALSE_POSITIVE : FIX_AVAILABLE;

  return {
    ...attributes,
    [key]: true,
  };
}

/**
 * Select/deselect filters
 * @param filter needs to be toggled
 * @param filters source object with all filters
 * @param onAttribute custom logic for attributes if required
 * @param vulnerabilityAttributes has more complex logic, requires whole object
 * @returns {*}
 */
export function selectFilter(filter, filters, { onAttribute, vulnerabilityAttributes } = {}) {
  switch (filter) {
    case STATUS:
      return enableStatusFilter(filters);
    case ATTRIBUTE:
      if (onAttribute) {
        onAttribute(enableAttributeFilter(vulnerabilityAttributes));
      }
      return filters;
    default:
      return {
        ...filters,
        [filter]: [],
      };
  }
}

/**
 * Remove property from payload
 * @param payload
 * @param key to be removed
 * @returns {Omit<{}, never>}
 */
export const removePropertyFromPayload = (payload, key = '') => {
  return omit(payload, [key]);
};

/**
 * Generate custom tooltip for age filter
 * @param filter
 * @param vulnerabilityStates
 * @returns {*|string}
 */
export function getAgeTooltip(filter, vulnerabilityStates) {
  switch (filter.value) {
    case AGE:
      if (!vulnerabilityStates[PREVIOUSLY_EXISTING]?.length) {
        return filter.tooltip[AGE_TOOLTIP_NO_PREVIOUSLY_EXISTING_VULNERABILITY];
      }
      return filter.tooltip[AGE_TOOLTIP_MAXIMUM_REACHED];
    default:
      return '';
  }
}

/**
 * Some yaml properties represented through empty array
 * when all items selected
 * @param values
 * @param allCount
 * @returns {*[]|any[]}
 */
export const selectEmptyArrayWhenAllSelected = (values = [], allCount) => {
  if (!Array.isArray(values) || Number.isNaN(Number(allCount))) {
    return [];
  }

  return values.length === allCount ? [] : values;
};

/**
 * Get collapse icon based on visibility state
 * @param isVisible
 * @returns {string}
 */
export const getCollapseIcon = (isVisible) => {
  return isVisible ? 'chevron-up' : 'chevron-down';
};

/**
 * Get vulnerabilities operator based on allowed count
 * @param vulnerabilitiesAllowed
 * @returns {string}
 */
export const getSelectedVulnerabilitiesOperator = (vulnerabilitiesAllowed) => {
  return vulnerabilitiesAllowed === 0 ? ANY_OPERATOR : GREATER_THAN_OPERATOR;
};

/**
 * Remove branch exceptions from scanner object
 * @param scanner
 * @returns {Object}
 */
export const removeExceptionsFromScanner = (scanner) => {
  const updatedScanner = { ...scanner };
  if (BRANCH_EXCEPTIONS_KEY in updatedScanner) {
    delete updatedScanner[BRANCH_EXCEPTIONS_KEY];
  }
  return updatedScanner;
};

/**
 * Update severity levels on scanner object
 * @param scanner
 * @param value
 * @returns {Object}
 */
export const updateSeverityLevels = (scanner, value) => {
  const updatedScanner = { ...scanner };
  if (value && value.length > 0) {
    updatedScanner.severity_levels = value;
  } else {
    delete updatedScanner.severity_levels;
  }
  return updatedScanner;
};

/**
 * Builds merged vulnerability attributes preserving KEV, EPSS, and enrichment data settings.
 *
 * Uses `!= null` instead of a falsy check for EPSS values because 0 is a
 * valid EPSS score ("flag all vulnerabilities regardless of EPSS score").
 * A falsy check would silently drop the attribute when value is 0.
 *
 * @param {Object} params
 * @param {Object} params.attributes - new fix_available/false_positive attributes to set
 * @param {*} params.kevFilterValue - current KEV filter value
 * @param {*} params.epssOperator - current EPSS operator
 * @param {*} params.epssValue - current EPSS value
 * @param {String} [params.enrichmentDataAction] - current enrichment_data_unavailable action ('block' or 'ignore')
 * @returns {Object|null} merged vulnerability_attributes, or null if empty (caller should strip the key)
 */
export const buildVulnerabilityAttributes = ({
  attributes,
  kevFilterValue,
  epssOperator,
  epssValue,
  enrichmentDataAction,
}) => {
  const kevAttribute = kevFilterValue ? { [KNOWN_EXPLOITED]: kevFilterValue } : {};
  const epssAttribute =
    epssOperator != null && epssValue != null
      ? { [EPSS_SCORE]: { operator: epssOperator, value: epssValue } }
      : {};
  const enrichmentAttribute = enrichmentDataAction
    ? { [ENRICHMENT_DATA_UNAVAILABLE]: { action: enrichmentDataAction } }
    : {};

  const hasAttributes = Object.keys(attributes).length > 0;

  const merged = {
    ...kevAttribute,
    ...epssAttribute,
    ...enrichmentAttribute,
    ...(hasAttributes ? attributes : {}),
  };

  return Object.keys(merged).length === 0 ? null : merged;
};

// Treat null/non-object `vulnerability_attributes` as empty so YAML quirks
// (e.g. an explicit `vulnerability_attributes: ~`) don't crash destructuring.
const safeAttributes = (scanner) => {
  const attributes = scanner?.vulnerability_attributes;
  return attributes && typeof attributes === 'object' && !Array.isArray(attributes)
    ? attributes
    : {};
};

/**
 * Strip KEV/EPSS exploit-settings attributes from a scanner. If no other
 * vulnerability_attributes remain, drop the wrapper key entirely.
 * @param {Object} scanner
 * @returns {Object}
 */
export const removeExploitSettingsFromScanner = (scanner) => {
  const { vulnerability_attributes: _va, ...rest } = scanner;
  const { [KNOWN_EXPLOITED]: _kev, [EPSS_SCORE]: _epss, ...remaining } = safeAttributes(scanner);

  if (Object.keys(remaining).length === 0) return rest;
  return { ...rest, vulnerability_attributes: remaining };
};

/**
 * Merge default KEV/EPSS exploit-settings values into a scanner's existing
 * vulnerability_attributes. Used when the user re-adds the Exploit Settings
 * section through the rule's "+ Add criteria" selector. Existing KEV/EPSS
 * values on the scanner take precedence over the defaults — defaults only
 * fill the gap.
 * @param {Object} scanner
 * @returns {Object} merged vulnerability_attributes
 */
export const buildExploitSettingsAttributes = (scanner) => {
  return {
    [KNOWN_EXPLOITED]: true,
    [EPSS_SCORE]: { operator: GREATER_THAN_OPERATOR, value: DEFAULT_EPSS_VALUE },
    ...safeAttributes(scanner),
  };
};
