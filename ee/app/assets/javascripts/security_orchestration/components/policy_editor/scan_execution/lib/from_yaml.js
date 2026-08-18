import { isEmpty } from 'lodash-es';
import {
  DEFAULT_TEMPLATE,
  LATEST_TEMPLATE,
  VERSIONED_TEMPLATES,
} from 'ee/security_orchestration/components/policy_editor/scan_execution/action/scan_filters/constants';
import { fromYaml } from 'ee/security_orchestration/components/utils';
import { SCAN_EXECUTION_POLICY_TYPE } from 'ee/security_orchestration/components/constants';
import { hasConflictingKeys, hasInvalidCron } from '../../utils';
import { BRANCH_TYPE_KEY, VALID_SCAN_EXECUTION_BRANCH_TYPE_OPTIONS } from '../../constants';
import { SCAN_EXECUTION_SCANNERS } from '../constants';

const VERSIONED_TEMPLATE_TYPES = Object.keys(VERSIONED_TEMPLATES);

/**
 * Check if any rule has invalid branch type
 * @param rules list of rules with either branches or branch_type property
 * @returns {Boolean}
 */
const hasInvalidBranchType = (rules) => {
  if (!rules) return false;

  return rules.some(
    (rule) =>
      BRANCH_TYPE_KEY in rule &&
      !VALID_SCAN_EXECUTION_BRANCH_TYPE_OPTIONS.includes(rule.branch_type),
  );
};

/**
 * Check if any action has invalid template type
 * @param {Array} actions
 * @returns {Boolean}
 */
export const hasInvalidTemplate = (actions = []) => {
  return actions.some(({ template, scan }) => {
    if (!template && template !== '') {
      return false;
    }

    // Allow versioned templates for dependency_scanning
    if (
      VERSIONED_TEMPLATE_TYPES.includes(scan) &&
      VERSIONED_TEMPLATES[scan].map(({ value }) => value).includes(template)
    ) {
      return false;
    }

    // For other scan types, only allow default or latest
    return ![DEFAULT_TEMPLATE, LATEST_TEMPLATE].includes(template);
  });
};

/**
 * Checks if any action has invalid scanner type
 * @param {Array} actions
 * @returns {Boolean} if all inputted scanners are in the available scanners dictionary
 */
export const hasInvalidScanners = (actions = []) => {
  if (!actions.length) return false;

  const availableScanners = Object.keys(SCAN_EXECUTION_SCANNERS);

  const configuredScanners = actions.map((action) => action.scan);
  return configuredScanners.some((scanner) => !availableScanners.includes(scanner));
};

/**
 * Validate policy actions and rules keys
 * @param policy
 * @returns {Object} errors object. If empty, policy is valid.
 */
export const validatePolicy = (policy) => {
  if (isEmpty(policy)) {
    return {
      actions: true,
      rules: true,
    };
  }

  const error = {};
  if (
    hasConflictingKeys(policy.rules) ||
    hasInvalidBranchType(policy.rules) ||
    hasInvalidCron(policy.rules)
  ) {
    error.rules = true;
  }

  if (hasInvalidTemplate(policy.actions) || hasInvalidScanners(policy.actions)) {
    error.actions = true;
  }

  return error;
};

/**
 * Converts a security policy from yaml to an object
 * @param {String} manifest a security policy in yaml form
 * @param {Boolean} addIds
 * @returns {Object} security policy object and any errors
 */
export const createPolicyObject = (manifest, addIds = true) => {
  const policy = fromYaml({
    manifest,
    type: SCAN_EXECUTION_POLICY_TYPE,
    addIds,
  });
  const parsingError = validatePolicy(policy);

  return { policy, parsingError };
};
