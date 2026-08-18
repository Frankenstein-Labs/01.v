import { safeLoad } from 'js-yaml';
import { isEmpty, uniqueId, isObject } from 'lodash-es';
import { NAMESPACE_TYPES } from 'ee/security_orchestration/constants';
import spepTestRunUpdatedSubscription from 'ee/security_orchestration/graphql/subscriptions/spep_test_run_updated.subscription.graphql';
import {
  REPORT_TYPE_DEPENDENCY_SCANNING,
  REPORT_TYPE_CONTAINER_SCANNING,
} from '~/vue_shared/security_reports/constants';
import { SCAN_EXECUTION_RULES_SCHEDULE_KEY } from 'ee/security_orchestration/components/policy_editor/scan_execution/constants';
import { TEST_RUN_STATES } from 'ee/security_orchestration/components/policies/constants';
import { APPROVAL_POLICY_TYPE, POLICY_TYPE_COMPONENT_OPTIONS } from './constants';

export const isPolicyInherited = (source) => source?.inherited === true;

export const policyHasNamespace = (source) => Boolean(source?.namespace);

/**
 * Check if namespace is a project type
 * @param namespaceType
 * @returns {boolean}
 */
export const isProject = (namespaceType) => namespaceType === NAMESPACE_TYPES.PROJECT;

/**
 * Check if namespace is a group type
 * @param namespaceType
 * @returns {boolean}
 */
export const isGroup = (namespaceType) => namespaceType === NAMESPACE_TYPES.GROUP;

/**
 * Returns if scanner has "scanning" in it
 * @param {string} scanner
 * @returns {boolean}
 */
export const isScanningReport = (scanner) =>
  [REPORT_TYPE_CONTAINER_SCANNING, REPORT_TYPE_DEPENDENCY_SCANNING].includes(scanner);

/**
 * Extracts the policy content from a YAML object with a type as the root property
 *
 * @param {Object} parsedYaml - The parsed YAML object representing a policy.
 * @param {string} type - The expected root property type to extract from `policyYaml`.
 * @returns {Object} - The extracted policy content, or the entire YAML object if no matching type is found.
 */
export const extractPolicyContentFromRootTypeProperty = (parsedYaml, type) => {
  if (type in parsedYaml) {
    return parsedYaml[type];
  }

  // Handle unknown root type property
  const policyKeys = Object.keys(parsedYaml);
  if (policyKeys.length === 1) {
    const rootProperty = policyKeys[0];
    const rootValue = parsedYaml[rootProperty];

    if (isObject(rootValue)) {
      return rootValue;
    }
  }

  return parsedYaml;
};

/**
 * Policy type, in this case, policy type is a wrapper
 * for a policy content. This method extracts policy content from
 * a wrapper
 * @param manifest policy in yaml format
 * @param type policy type
 * @param withType whether include or not include type property in a policy body
 * @returns {*|{policy: {}}}
 */
export const extractPolicyContent = ({ manifest, type, withType = false }) => {
  const defaultPayload = {};

  try {
    const parsedYaml = safeLoad(manifest, { json: true });
    /**
     * Remove type property from yaml
     * Type now is a parent property
     */
    const hasLegacyTypeRootProperty = 'type' in parsedYaml;
    if (hasLegacyTypeRootProperty) {
      delete parsedYaml.type;
    }

    const extractedPolicy = extractPolicyContentFromRootTypeProperty(parsedYaml, type);

    const isArray = Array.isArray(extractedPolicy);
    const policy = isArray ? extractedPolicy[0] : extractedPolicy;

    if (withType) {
      policy.type = type;
    }

    return policy || defaultPayload;
  } catch {
    return defaultPayload;
  }
};

export const addIdsToPolicy = (policy) => {
  const updatedPolicy = { ...policy };

  if (updatedPolicy.actions) {
    updatedPolicy.actions = policy.actions?.map((action) => ({
      ...action,
      id: uniqueId('action_'),
    }));
  }

  if (updatedPolicy.rules) {
    updatedPolicy.rules = policy.rules?.map((action) => ({ ...action, id: uniqueId('rule_') }));
  }

  return updatedPolicy;
};

/**
 * Construct a policy object expected by the policy editor from a yaml manifest.
 * @param {Object} options
 * @param {String}  options.manifest a security policy in yaml form
 * @returns {Object} security policy as JS object
 */
export const fromYaml = ({ manifest, type = APPROVAL_POLICY_TYPE, addIds = true }) => {
  try {
    const payload = extractPolicyContent({
      manifest,
      type,
      withType: true,
    });

    return addIds ? addIdsToPolicy(payload) : payload;
  } catch {
    /**
     * Catch parsing error of safeLoad
     */
    return {};
  }
};

/**
 * Check if the policy is a scan execution policy and has a scheduled rule
 * @param {Object} policy
 * @returns {Boolean}
 */
export const hasScheduledRule = (policy) => {
  let policyObject = policy;

  // Handle policy list policies
  if (
    policyObject.yaml &&
    // eslint-disable-next-line no-underscore-dangle
    policyObject.__typename === POLICY_TYPE_COMPONENT_OPTIONS.scanExecution.typeName
  ) {
    policyObject = fromYaml({ manifest: policyObject.yaml });
  }

  return policyObject?.rules?.some(({ type }) => type === SCAN_EXECUTION_RULES_SCHEDULE_KEY);
};

/**
 * Check if policy scope is in default mode (no frameworks, no excluding/including projects)
 * @param {Object} policyScope
 * @returns {boolean}
 */
export const isDefaultMode = (policyScope) => {
  const {
    complianceFrameworks: { nodes: frameworks } = {},
    excludingProjects: { nodes: excluding } = {},
    includingProjects: { nodes: including } = {},
  } = policyScope || {};
  const noScope = (items) => !items || items.length === 0;
  const existingDefaultScope = noScope(frameworks) && noScope(excluding) && noScope(including);
  return (
    policyScope === undefined ||
    policyScope === null ||
    isEmpty(policyScope) ||
    existingDefaultScope
  );
};

export const checkForPerformanceRisk = ({ policy, namespaceType, projectsCount }) => {
  const PROJECTS_COUNT_PERFORMANCE_LIMIT = 1000;

  return (
    hasScheduledRule(policy) &&
    isGroup(namespaceType) &&
    projectsCount > PROJECTS_COUNT_PERFORMANCE_LIMIT
  );
};

const ACTIVE_TEST_RUN_STATES = [
  TEST_RUN_STATES.RUNNING,
  TEST_RUN_STATES.CREATING,
  TEST_RUN_STATES.PENDING,
];

const isTestRunActive = (testRun) =>
  Boolean(testRun?.id) && !testRun.completed && ACTIVE_TEST_RUN_STATES.includes(testRun.state);

export const createSpepTestRunSubscription = (getterProp, setterProp) => ({
  query: spepTestRunUpdatedSubscription,
  variables() {
    return { testRunId: this[getterProp]?.id };
  },
  result({ data: { securityPolicyScheduleTestRunUpdated } }) {
    if (securityPolicyScheduleTestRunUpdated) {
      this[setterProp] = securityPolicyScheduleTestRunUpdated;
    }
  },
  skip() {
    return !isTestRunActive(this[getterProp]);
  },
});
