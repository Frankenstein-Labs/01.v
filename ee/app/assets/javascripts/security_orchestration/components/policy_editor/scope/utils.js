import { uniqueId } from 'lodash-es';
import { TYPENAME_SECURITY_ATTRIBUTE } from 'ee/graphql_shared/constants';
import { convertToGraphQLId } from '~/graphql_shared/utils';
import { slugifyWithUnderscore } from '~/lib/utils/text_utility';
import { EXCLUDING, INCLUDING, RESERVED_SCOPE_KEYS } from './constants';

/**
 * Derive YAML key from a security category.
 * Uses templateType for built-in categories (e.g. BUSINESS_IMPACT → business_impact),
 * falls back to slugified name for custom categories (templateType: null).
 *
 * @param {Object} category - Security category object
 * @param {string|null} category.templateType - e.g. 'BUSINESS_IMPACT' or null
 * @param {string} category.name - e.g. 'Business Impact' or 'New Category'
 * @returns {string} YAML key e.g. 'business_impact' or 'new_category'
 */
export const categoryToYamlKey = (category) =>
  category.templateType?.toLowerCase() ?? slugifyWithUnderscore(category.name);

export const getInitialCategoryKey = (policyScope = {}) =>
  Object.keys(policyScope).find(
    (key) =>
      !RESERVED_SCOPE_KEYS.includes(key) &&
      (policyScope[key]?.including || policyScope[key]?.excluding),
  ) || null;

export const getInitialExceptionType = (policyScope = {}) => {
  const key = getInitialCategoryKey(policyScope);
  if (key && Array.isArray(policyScope[key]?.excluding)) return EXCLUDING;
  return INCLUDING;
};

const mapToGraphQLIds = (source) =>
  Array.isArray(source)
    ? source.map(({ id }) => convertToGraphQLId(TYPENAME_SECURITY_ATTRIBUTE, id))
    : [];

export const getInitialIncludingAttributeIds = (policyScope = {}) => {
  const key = getInitialCategoryKey(policyScope);
  if (!key) return [];
  return mapToGraphQLIds(policyScope[key]?.including);
};

export const getInitialExcludingAttributeIds = (policyScope = {}) => {
  const key = getInitialCategoryKey(policyScope);
  if (!key) return [];
  return mapToGraphQLIds(policyScope[key]?.excluding);
};

export const getNonReservedScope = (policyScope = {}) =>
  Object.fromEntries(
    Object.entries(policyScope || {}).filter(([key]) => !RESERVED_SCOPE_KEYS.includes(key)),
  );

export const getReservedScope = (policyScope = {}) =>
  Object.fromEntries(
    Object.entries(policyScope || {}).filter(([key]) => RESERVED_SCOPE_KEYS.includes(key)),
  );

export const buildRows = (policyScope = {}) => {
  const rows = Object.entries(getNonReservedScope(policyScope)).map(([key, value]) => ({
    id: uniqueId('scope-row-'),
    scope: { [key]: value },
  }));
  if (rows.length === 0) rows.push({ id: uniqueId('scope-row-'), scope: {} });
  return rows;
};
