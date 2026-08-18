import { get } from 'lodash-es';

/**
 * Helper function for accessing nested properties with consistent default values
 * @param {Object} source - The source object
 * @param {String} path - The path to access, using dot notation
 * @param {*} defaultValue - Default value to return if path doesn't exist
 * @returns {*} The value at the path or the default value
 */
export const getData = (source, path, defaultValue = undefined) => get(source, path, defaultValue);

/**
 * Helper to extract pagination info with consistent structure
 * @param {Object} data - The source data object
 * @param {String} path - Path to the pageInfo object
 * @returns {Object} Normalized page info object
 */
export const getPageInfo = (data, path) => {
  const pageInfo = getData(data, path, {});
  return {
    hasNextPage: Boolean(pageInfo.hasNextPage),
    endCursor: pageInfo.endCursor || null,
  };
};
