import { s__ } from '~/locale';
import { searchInItemsProperties } from '~/lib/utils/search_utils';
import {
  LOW_RISK,
  MODERATE_RISK,
  HIGH_RISK,
  CRITICAL_RISK,
  CUSTOM_VALUE,
  ENRICHMENT_DATA_UNAVAILABLE,
  ENRICHMENT_DATA_ACTIONS,
} from './constants';

export const filterLicenseItems = (allItems, searchTerm = '', currentLicense = '') => {
  let items = allItems;

  if (searchTerm) {
    items = searchInItemsProperties({
      items,
      properties: ['text', 'value'],
      searchQuery: searchTerm,
    });

    const lowerSearchTerm = searchTerm.toLowerCase();
    const exactMatch = items.some(
      (l) =>
        l.text?.toLowerCase() === lowerSearchTerm || l.value?.toLowerCase() === lowerSearchTerm,
    );

    if (!exactMatch) {
      items = [
        { value: searchTerm, text: `${searchTerm} (${s__('ScanResultPolicy|custom')})` },
        ...items,
      ];
    }
  }

  if (currentLicense && !items.some((l) => l.value === currentLicense)) {
    items = [{ value: currentLicense, text: currentLicense }, ...items];
  }

  return items;
};

const PREDEFINED_VALUES = [LOW_RISK, HIGH_RISK, MODERATE_RISK, CRITICAL_RISK];

/**
 * Extract percent value from string like Critical Risk (100%)
 * It would result into 100 and returns 1
 * @param value
 * @returns {undefined|number}
 */
export const extractPercentValue = (value = '') => {
  if (!value) return undefined;

  const match = value.match(/\((\d+(?:\.\d+)?)%\)/);

  if (match) {
    const number = parseFloat(match[1]);
    return number / 100;
  }

  return undefined;
};

/**
 * Based on input Like 1|0.5|0.3 it would return one of
 * predefined values like Critical Risk (100%)
 * @param value
 * @returns {undefined|*}
 */
export const convertToPercentString = (value) => {
  if (!value || Number.isNaN(Number(value))) return undefined;

  const convertedPercent = value * 100;
  if (convertedPercent === 0) return undefined;

  return PREDEFINED_VALUES.find((v) => v.includes(convertedPercent.toString())) || CUSTOM_VALUE;
};

/**
 * If value is not in the list of predefined values
 * it means it is custom value
 * @param value
 * @returns {boolean}
 */
export const isCustomEpssValue = (value) => {
  if (!value || Number.isNaN(Number(value))) return false;

  const convertedPercent = value * 100;
  if (convertedPercent === 0) return false;

  return PREDEFINED_VALUES.find((v) => v.includes(convertedPercent.toString())) === undefined;
};

/**
 * Checks whether a value is a valid enrichment data action ('block' or 'ignore').
 * @param {*} value - The action value to validate
 * @returns {Boolean}
 */
export const isValidEnrichmentDataAction = (value) =>
  Object.values(ENRICHMENT_DATA_ACTIONS).includes(value);

/**
 * Extracts the enrichment_data_unavailable action from a scanner's vulnerability attributes,
 * falling back to 'block' when the attribute is absent.
 * @param {Object} scanner - Scanner object with optional vulnerability_attributes
 * @returns {String} 'block' or 'ignore'
 */
export const getEnrichmentDataAction = (scanner) =>
  scanner?.vulnerability_attributes?.[ENRICHMENT_DATA_UNAVAILABLE]?.action ??
  ENRICHMENT_DATA_ACTIONS.BLOCK;
