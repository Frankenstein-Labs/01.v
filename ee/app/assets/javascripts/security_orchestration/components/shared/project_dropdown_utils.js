import { debounce } from 'lodash-es';
import { n__, __ } from '~/locale';
import { searchInItemsProperties } from '~/lib/utils/search_utils';
import { DEFAULT_DEBOUNCE_AND_THROTTLE_MS } from '~/lib/utils/constants';

export const PROJECT_DROPDOWN_I18N = {
  projectDropdownHeader: __('Select projects'),
};

/**
 * Creates a debounced search function for project dropdowns.
 * @param {Function} setSearchTermFn - The function to call with the search term
 * @returns {Function} Debounced search function
 */
export const createDebouncedSearch = (setSearchTermFn) =>
  debounce(setSearchTermFn, DEFAULT_DEBOUNCE_AND_THROTTLE_MS);

/**
 * Normalizes a search term by trimming whitespace.
 * @param {string} searchTerm - The search term to normalize
 * @returns {string} Normalized search term
 */
export const normalizeSearchTerm = (searchTerm = '') => searchTerm.trim();

/**
 * Transforms projects array into listbox items format.
 * @param {Array} projects - Array of project objects with id, name, fullPath
 * @param {string} searchTerm - Optional search term to filter results
 * @returns {Array} Array of listbox items with text, value, fullPath
 */
export const projectsToListboxItems = (projects, searchTerm = '') => {
  const items = projects.map(({ id, fullPath, name }) => ({
    text: name,
    value: id,
    fullPath,
  }));

  return searchInItemsProperties({
    items,
    properties: ['text', 'fullPath'],
    searchQuery: searchTerm,
  });
};

/**
 * Returns the category prop value for dropdown based on validation state.
 * @param {boolean} state - Validation state (true = valid, false = invalid)
 * @returns {string} Category value ('primary' or 'secondary')
 */
export const getDropdownCategory = (state) => (state ? 'primary' : 'secondary');

/**
 * Returns the variant prop value for dropdown based on validation state.
 * @param {boolean} state - Validation state (true = valid, false = invalid)
 * @returns {string} Variant value ('default' or 'danger')
 */
export const getDropdownVariant = (state) => (state ? 'default' : 'danger');

/**
 * Gets the projects text (pluralized) for footer display.
 * @param {number} count - Number of projects
 * @returns {string} Pluralized text ('project' or 'projects')
 */
export const getProjectsText = (count) => n__('project', 'projects', count);

/**
 * Filters selected IDs to only include those that exist in the projects list.
 * @param {Array} selectedIds - Array of selected project IDs
 * @param {Array} projectIds - Array of available project IDs
 * @returns {Array} Filtered array of selected IDs that exist in projects
 */
export const filterExistingSelectedIds = (selectedIds, projectIds) =>
  selectedIds.filter((id) => projectIds.includes(id));

/**
 * Shared props definition for project dropdown components.
 */
export const SHARED_DROPDOWN_PROPS = {
  disabled: {
    type: Boolean,
    required: false,
    default: false,
  },
  placement: {
    type: String,
    required: false,
    default: 'bottom-start',
  },
  selected: {
    type: [Array, String],
    required: false,
    default: () => [],
  },
  state: {
    type: Boolean,
    required: false,
    default: false,
  },
  withProjectCount: {
    type: Boolean,
    required: false,
    default: false,
  },
};
