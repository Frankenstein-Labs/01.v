import { isBoolean, isEmpty, isEqual } from 'lodash-es';
import { s__ } from '~/locale';
import { APPROVAL_POLICY_TYPE } from 'ee/security_orchestration/components/constants';
import { fromYaml } from 'ee/security_orchestration/components/utils';
import { hasInvalidKey } from '../../utils';
import { OPEN, CLOSED } from '../advanced_settings/constants';
import { hasInvalidRules } from './rules';
import { REQUIRE_APPROVAL_TYPE } from './actions';
import {
  BLOCK_GROUP_BRANCH_MODIFICATION,
  PROJECT_LEVEL_CONFIGURATION_KEYS,
  VALID_APPROVAL_SETTINGS,
  PERMITTED_INVALID_SETTINGS,
  PERMITTED_INVALID_SETTINGS_KEY,
} from './settings';
import { WARN_VALUE } from './enforcement';

const I18N = {
  settingWarningTitle: s__(
    'SecurityOrchestration|Only overriding settings and bot message will take effect',
  ),
  enforcedSettingWarningDescription: s__(
    "SecurityOrchestration|For any merge request that matches this policy's rules, no action is applied. This policy overrides the project approval settings and notifies users with a bot message, which means that no approvals are required.",
  ),
  settingErrorTitle: s__('SecurityOrchestration|Cannot create an empty policy'),
  settingErrorDescription: s__(
    "SecurityOrchestration|This policy doesn't contain any actions or override project approval settings. You cannot create an empty policy.",
  ),
  warnSettingWarningDescription: s__(
    "SecurityOrchestration|For any merge request that matches this policy's rules, no action is applied. Users are warned about project approval settings that could have been overridden, if the policy were enforced rather than in warn mode, through a bot message. No additional approvals are required.",
  ),
  noRulesWarningTitle: s__('SecurityOrchestration|Only project approval settings will take effect'),
  noRulesWarningDescription: s__(
    'SecurityOrchestration|This policy has no rules, so branch-level settings will not be applied. Only project approval settings will take effect.',
  ),
  noRulesErrorTitle: s__('SecurityOrchestration|Policy will have no effect'),
  noRulesErrorDescription: s__(
    'SecurityOrchestration|This policy has no rules to match merge requests against. Add rules for this policy to take effect.',
  ),
};

const ALERT_CONFIGS = {
  noAlert: { show: false, config: null },
  noRulesNoApprovalWarning: {
    show: true,
    config: {
      variant: 'warning',
      title: I18N.noRulesWarningTitle,
      description: I18N.noRulesWarningDescription,
    },
  },
  noRulesNoApprovalError: {
    show: true,
    config: {
      variant: 'danger',
      title: I18N.settingErrorTitle,
      description: I18N.settingErrorDescription,
    },
  },
  noRulesApprovalWarning: {
    show: true,
    config: {
      variant: 'warning',
      title: I18N.noRulesWarningTitle,
      description: I18N.noRulesWarningDescription,
    },
  },
  noRulesApprovalError: {
    show: true,
    config: {
      variant: 'danger',
      title: I18N.noRulesErrorTitle,
      description: I18N.noRulesErrorDescription,
    },
  },
  rulesNoApprovalError: {
    show: true,
    config: {
      variant: 'danger',
      title: I18N.settingErrorTitle,
      description: I18N.settingErrorDescription,
    },
  },
  rulesNoApprovalWarning: (warnMode) => ({
    show: true,
    config: {
      variant: 'warning',
      title: I18N.settingWarningTitle,
      description: warnMode
        ? I18N.warnSettingWarningDescription
        : I18N.enforcedSettingWarningDescription,
    },
  }),
};

/**
 * Checks if the policy actions include a require_approval action
 * @param {Array<Object>} actions - Array of policy action objects
 * @returns {boolean} True if actions contain a require_approval type action
 */
export const hasRequireApprovalAction = (actions) => {
  return (actions || []).some(({ type }) => type === REQUIRE_APPROVAL_TYPE);
};

/**
 * Checks if the policy has valid rules defined
 * @param {Array<Object>} rules - Array of policy rule objects
 * @returns {boolean} True if rules exist and the first rule has a non-empty type
 */
export const hasRules = (rules) => {
  if (!rules || rules.length === 0) {
    return false;
  }
  return rules[0]?.type !== '';
};

/**
 * Checks if the policy has any enabled approval settings
 * Excludes permitted invalid settings and handles block_group_branch_modification specially
 * @param {Object} approvalSettings - Policy approval settings object
 * @returns {boolean} True if any valid approval setting is enabled
 */
export const hasSettings = (approvalSettings) => {
  if (isEmpty(approvalSettings)) {
    return false;
  }
  return Object.entries(approvalSettings).some(([key, value]) => {
    if (key === PERMITTED_INVALID_SETTINGS_KEY) {
      return false;
    }

    if (key === BLOCK_GROUP_BRANCH_MODIFICATION && typeof value !== 'boolean') {
      return value && value.enabled === true;
    }

    return value;
  });
};

/**
 * Checks if any project-level approval setting is enabled
 * Considers both merge-request-scope and project-wide-scope settings
 * @param {Object} approvalSettings - Policy approval settings object
 * @returns {boolean} True if any project-level approval setting is enabled
 */
export const hasEnabledProjectSettings = (approvalSettings) => {
  if (isEmpty(approvalSettings)) {
    return false;
  }
  return PROJECT_LEVEL_CONFIGURATION_KEYS.some((key) => Boolean(approvalSettings[key]));
};

/**
 * Determines the alert configuration to display based on policy state
 * Returns alert variant, title, and description based on rules, actions, and settings
 * @param {Object} policy - The policy object containing rules, actions, and approval_settings
 * @param {Object} [parsingError={}] - Object containing parsing error flags
 * @returns {{show: boolean, config: {variant: string, title: string, description: string}|null}}
 *   Alert configuration with show flag and config object (or null if no alert should show)
 */
export const getSettingAlertConfig = (policy, parsingError = {}) => {
  const hasNonActionParsingErrors = Object.keys(parsingError).some(
    (key) => key !== 'actions' && parsingError[key],
  );
  if (hasNonActionParsingErrors) {
    return ALERT_CONFIGS.noAlert;
  }

  const rules = hasRules(policy.rules);
  const requireApproval = hasRequireApprovalAction(policy.actions);
  const settings = hasSettings(policy.approval_settings);
  const projectSettings = hasEnabledProjectSettings(policy.approval_settings);
  const warnMode = policy.enforcement_type === WARN_VALUE;

  if (rules && requireApproval) {
    return ALERT_CONFIGS.noAlert;
  }

  if (!rules && !requireApproval) {
    return projectSettings
      ? ALERT_CONFIGS.noRulesNoApprovalWarning
      : ALERT_CONFIGS.noRulesNoApprovalError;
  }

  if (!rules && requireApproval) {
    return projectSettings
      ? ALERT_CONFIGS.noRulesApprovalWarning
      : ALERT_CONFIGS.noRulesApprovalError;
  }

  if (rules && !requireApproval) {
    return !settings
      ? ALERT_CONFIGS.rulesNoApprovalError
      : ALERT_CONFIGS.rulesNoApprovalWarning(warnMode);
  }

  return ALERT_CONFIGS.noAlert;
};

/**
 * Validate policy properties that would break rule mode
 * @param {Object} policy
 * @returns {Object} Errors object. If empty, policy is valid.
 */
export const validatePolicy = (policy) => {
  if (isEmpty(policy)) {
    return {
      actions: true,
      rules: true,
      fallback: true,
      settings: true,
    };
  }

  const error = {};
  if (hasInvalidRules(policy.rules)) {
    error.rules = true;
  }

  const { approval_settings: approvalSettings = {}, fallback_behavior: fallback = {} } = policy;

  // Temporary workaround to allow the rule builder to load with wrongly persisted settings
  const hasInvalidApprovalSettings = hasInvalidKey(approvalSettings, [
    ...VALID_APPROVAL_SETTINGS,
    PERMITTED_INVALID_SETTINGS_KEY,
  ]);

  const hasInvalidSettingStructure = () => {
    if (isEqual(approvalSettings, PERMITTED_INVALID_SETTINGS)) {
      return false;
    }

    return !Object.entries(approvalSettings).every(
      ([key, value]) => isBoolean(value) || key === BLOCK_GROUP_BRANCH_MODIFICATION,
    );
  };

  if (hasInvalidApprovalSettings || hasInvalidSettingStructure()) {
    error.settings = true;
  }

  const hasInvalidFallbackBehavior = !isEmpty(fallback) && ![OPEN, CLOSED].includes(fallback.fail);

  if (hasInvalidFallbackBehavior) {
    error.fallback = true;
  }

  return error;
};

/**
 * Converts a security policy from yaml to an object
 * @param {String} manifest a security policy in yaml form
 * @returns {Object} security policy object and any errors
 */
export const createPolicyObject = (manifest) => {
  const policy = fromYaml({ manifest, type: APPROVAL_POLICY_TYPE });
  const parsingError = validatePolicy(policy);

  return { policy, parsingError };
};
