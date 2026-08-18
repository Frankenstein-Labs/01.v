import { uniqueId, get } from 'lodash-es';
import {
  CUSTOM_ROLES,
  EXCEPTIONS_FULL_OPTIONS_MAP,
  ROLES,
} from 'ee/security_orchestration/components/policy_editor/scan_result/advanced_settings/constants';

const normalizeTarget = (target = {}) => {
  if (target.pattern !== undefined) {
    return target;
  }
  if (target.name !== undefined) {
    return { pattern: target.name };
  }
  return target;
};

export const createSourceBranchPatternObject = ({ id = '', source = {}, target = {} } = {}) => ({
  id: id || uniqueId('pattern_'),
  source,
  target: normalizeTarget(target),
});

export const createServiceAccountObject = ({ id = '' } = {}) => ({
  id: id || uniqueId('account_'),
});

/**
 * validate that account has all required properties
 * @param item
 * @returns {boolean}
 */
export const isValidServiceAccount = (item) => item && Boolean(item.name) && Boolean(item.username);

/**
 * remove ids from items
 * @param items
 * @returns {*[]}
 */
export const removeIds = (items = []) => {
  return items.map(({ id, ...item }) => ({ ...item }));
};
/**
 * Filter out invalid exceptions keys
 * @param keys
 * @returns {string[]};
 */
export const onlyValidKeys = (keys) => {
  const validKeys = Object.keys(EXCEPTIONS_FULL_OPTIONS_MAP);
  return keys.filter((key) => validKeys.includes(key));
};

export const countItemsLength = ({ source, key }) => {
  const getLength = (item) => (Array.isArray(item) ? item.length : 0);

  const baseCount = getLength(get(source, key, []));

  // For roles, include custom roles in the count
  if (key === ROLES) {
    const customRolesCount = getLength(get(source, CUSTOM_ROLES, []));
    return baseCount + customRolesCount;
  }

  return baseCount;
};
