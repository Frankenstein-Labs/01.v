import { isBoolean, isUndefined } from 'lodash-es';
import { CUSTOM_STRATEGY_OPTIONS_KEYS } from '../constants';

export const validateStrategyValues = (value) => CUSTOM_STRATEGY_OPTIONS_KEYS.includes(value);

/**
 * Validate keys and value types
 * of variables configuration
 * @param variablesOverride
 * @returns {arg is any[]|boolean}
 */
export const doesVariablesOverrideHasValidStructure = (variablesOverride = {}) => {
  const allowedKeys = ['allowed', 'exceptions'];
  const hasValidKeys = Object.keys(variablesOverride).every((key) => allowedKeys.includes(key));

  if (!hasValidKeys) {
    return false;
  }

  if (!isBoolean(variablesOverride.allowed)) {
    return false;
  }

  // `exceptions` are optional
  return isUndefined(variablesOverride.exceptions) || Array.isArray(variablesOverride.exceptions);
};
