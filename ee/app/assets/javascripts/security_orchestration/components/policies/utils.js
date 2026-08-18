import {
  BREAKING_CHANGES_POPOVER_CONTENTS,
  POLICY_SOURCE_OPTIONS,
  POLICY_TYPE_FILTER_OPTIONS,
} from 'ee/security_orchestration/components/policies/constants';
import { sprintf } from '~/locale';
import {
  POLICY_TYPE_COMPONENT_OPTIONS,
  SCAN_EXECUTION_POLICY_TYPE,
} from 'ee/security_orchestration/components/constants';
import { fromYaml, isPolicyInherited } from 'ee/security_orchestration/components/utils';
import { SCHEDULE } from 'ee/security_orchestration/components/policy_editor/pipeline_execution/constants';

/**
 * @param {Object} allowedValues
 * @param value
 * @param lowerCase
 * @returns {boolean}
 */
const validateFilter = (allowedValues, value, lowerCase = false) => {
  if (typeof value !== 'string') return false;

  return Object.values(allowedValues)
    .map((option) => (lowerCase ? option.value?.toLowerCase() : option.value))
    .includes(lowerCase ? value?.toLowerCase() : value);
};

/**
 * Check validity of value against allowed list
 * @param value
 * @returns {boolean}
 */
export const validateTypeFilter = (value) => {
  return validateFilter(POLICY_TYPE_FILTER_OPTIONS, value, true);
};

/**
 * Check validity of value against allowed list
 * @param value
 * @returns {boolean}
 */
export const validateSourceFilter = (value) => validateFilter(POLICY_SOURCE_OPTIONS, value, true);

/**
 * Conversion between lower case url params and policies
 * uppercase constants
 * @param type
 * @returns {string|undefined|string}
 */
export const extractTypeParameter = (type) => {
  // necessary for bookmarks of /-/security/policies?type=scan_result
  const updatedType = type === 'scan_result' ? 'approval' : type;
  return validateTypeFilter(updatedType)
    ? updatedType?.toUpperCase()
    : POLICY_TYPE_FILTER_OPTIONS.ALL.value;
};

/**
 * Conversion between lower case url params and policies
 * uppercase constants
 * @param source
 * @returns {string|undefined|string}
 */
export const extractSourceParameter = (source) =>
  validateSourceFilter(source) ? source?.toUpperCase() : POLICY_SOURCE_OPTIONS.ALL.value;

/**
 * Return true if number of scan execution policy actions exceeds allowed amount
 * @param {string} policyType
 * @param {string} yaml
 * @param {number} maxScanExecutionPolicyActions
 * @returns {boolean}
 */
export const exceedsActionLimit = ({ policyType, yaml, maxScanExecutionPolicyActions } = {}) => {
  if (maxScanExecutionPolicyActions === 0) {
    return false;
  }

  if (policyType === POLICY_TYPE_COMPONENT_OPTIONS.scanExecution.text) {
    const policy = fromYaml({
      manifest: yaml,
      type: SCAN_EXECUTION_POLICY_TYPE,
    });

    const { actions = [] } = policy;
    return actions.length > maxScanExecutionPolicyActions;
  }

  return false;
};

/**
 * Return true if number of scan execution policy scheduled rules allowed amount
 * @param policyType
 * @param yaml
 * @param maxScanExecutionPolicySchedules
 * @returns {boolean}
 */
export const exceedsScheduleRulesLimit = ({
  policyType,
  yaml,
  maxScanExecutionPolicySchedules,
}) => {
  if (maxScanExecutionPolicySchedules === 0) {
    return false;
  }

  if (policyType === POLICY_TYPE_COMPONENT_OPTIONS.scanExecution.text) {
    const policy = fromYaml({
      manifest: yaml,
      type: SCAN_EXECUTION_POLICY_TYPE,
    });

    const { rules = [] } = policy;

    return rules.filter(({ type }) => type === SCHEDULE).length > maxScanExecutionPolicySchedules;
  }

  return false;
};

/**
 * Build violation list based on conditions
 * @param {string} policyType
 * @param {Array} deprecatedProperties
 * @param {string} yaml
 * @param {number} maxScanExecutionPolicyActions
 * @param {number} maxScanExecutionPolicySchedules
 * @returns {string[]}
 */
export const buildPolicyViolationList = ({
  policyType,
  deprecatedProperties = [],
  yaml = '',
  maxScanExecutionPolicyActions,
  maxScanExecutionPolicySchedules,
}) => {
  const violationList = [];

  const hasDeprecatedProperties =
    Boolean(BREAKING_CHANGES_POPOVER_CONTENTS[policyType]) && deprecatedProperties?.length > 0;

  if (hasDeprecatedProperties) {
    violationList.push({
      content: sprintf(BREAKING_CHANGES_POPOVER_CONTENTS[policyType].content, {
        deprecatedProperties: deprecatedProperties.join(', '),
      }),
      link: BREAKING_CHANGES_POPOVER_CONTENTS[policyType].link,
    });
  }

  if (exceedsActionLimit({ policyType, yaml, maxScanExecutionPolicyActions })) {
    violationList.push({
      content: sprintf(BREAKING_CHANGES_POPOVER_CONTENTS.exceedingAction.content, {
        maxScanExecutionPolicyActions,
      }),
      link: BREAKING_CHANGES_POPOVER_CONTENTS.exceedingAction.link,
    });
  }

  if (
    exceedsScheduleRulesLimit({
      policyType,
      yaml,
      maxScanExecutionPolicySchedules,
    })
  ) {
    violationList.push({
      content: sprintf(BREAKING_CHANGES_POPOVER_CONTENTS.exceedingScheduledRules.content, {
        maxScanExecutionPolicySchedules,
      }),
      link: BREAKING_CHANGES_POPOVER_CONTENTS.exceedingScheduledRules.link,
    });
  }

  return violationList;
};

/**
 * Universal for all types policy structure
 * has policyAttributes properties wrapped in an object
 * this method unwraps it and merges into policy
 * @param {Array} policies array of generic policies
 */
export const flattenPolicies = (policies) => {
  if (!Array.isArray(policies)) return [];

  return policies.filter(Boolean).map(({ policyAttributes = {}, ...policy }) => ({
    ...policy,
    ...policyAttributes,
  }));
};

export const getTestRunsForProject = (testRuns, { isGroup, source, namespacePath }) => {
  if (isGroup || !isPolicyInherited(source)) {
    return testRuns ?? null;
  }
  const matchingNodes = testRuns?.nodes?.filter((run) => run.project?.fullPath === namespacePath);
  return matchingNodes?.length ? { nodes: matchingNodes } : null;
};
