import { isEqual } from 'lodash-es';
import { setUrlParams, updateHistory } from '~/lib/utils/url_utility';

/**
 * Creates a panel-specific parameter name to avoid conflicts
 *
 * @param {Object} options - The options object
 * @param {String} options.panelId - The unique panel identifier
 * @param {String} options.paramName - The parameter name
 * @returns {String} The prefixed parameter name
 */
export function getPanelParamName({ panelId, paramName }) {
  return `${panelId}.${paramName}`;
}

/**
 * Reads a value from URL query parameters
 *
 * @param {Object} options - The options object
 * @param {String} options.panelId - The id of the panel
 * @param {String} options.paramName - The parameter name to read
 * @param {*} options.defaultValue - Default value if parameter doesn't exist
 * @returns {*} The parameter value or default
 */
export function readFromUrl({ panelId, paramName, defaultValue }) {
  const panelParamName = getPanelParamName({ panelId, paramName });
  const params = new URLSearchParams(window.location.search);
  const value = params.get(panelParamName);

  if (value === null || value === '') {
    return defaultValue;
  }

  // Handle arrays (comma-separated values)
  if (Array.isArray(defaultValue)) {
    return value.split(',').filter((i) => i !== '');
  }

  // Handle numbers
  if (typeof defaultValue === 'number') {
    const parsed = parseInt(value, 10);
    return Number.isNaN(parsed) ? defaultValue : parsed;
  }

  // Handle strings
  return value;
}

/**
 * Writes a value to URL query parameters
 *
 * @param {Object} options - The options object
 * @param {String} options.panelId - The id of the panel
 * @param {String} options.paramName - The parameter name to write
 * @param {*} options.value - The value to write
 * @param {*} options.defaultValue - The default value (used to determine if we should remove the param)
 */

export function writeToUrl({ panelId, paramName, value, defaultValue }) {
  const panelParamName = getPanelParamName({ panelId, paramName });

  const isDefault = isEqual(value, defaultValue);
  const stringValue = Array.isArray(value) ? value.join(',') : String(value);
  const params = {};

  params[panelParamName] = isDefault ? undefined : stringValue;
  const url = setUrlParams(params, { url: window.location.href, decodeParams: true });

  updateHistory({ url, replace: true });
}
