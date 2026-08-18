import { safeDump, safeLoad } from 'js-yaml';
import { PIPELINE_EXECUTION_POLICY_TYPE } from 'ee/security_orchestration/components/constants';
import { fromYaml } from 'ee/security_orchestration/components/utils';
import { hasInvalidKey } from '../utils';
import {
  DEFAULT_SCHEDULE,
  DEFAULT_VARIABLES_OVERRIDE_STATE,
  PIPELINE_EXECUTION_SCHEDULE_POLICY,
  SCHEDULE,
} from './constants';

/**
 * Extract the strategy type from a `pipeline_config_strategy`, which the schema allows as either
 * a plain string or an object `{ type, apply_on_empty_pipeline }` (experimental).
 * @param {String|Object} strategy
 * @returns {String|undefined} the strategy type
 */
export const getPipelineConfigStrategyType = (strategy) =>
  strategy && typeof strategy === 'object' ? strategy.type : strategy;

/**
 * Update policy strategy and create new policy object with required properties
 * @param {Object} param
 * @param {Object} param.policy existing policy
 * @param {String} param.strategy new strategy
 * @returns {Object} new policy object
 */
export const updatePolicyStrategy = ({ policy, strategy }) => {
  let newPolicy;

  // `variables_override` is not supported by schedule type at the moment and needs to be handled differently.
  // Addressed by https://gitlab.com/gitlab-org/gitlab/-/issues/543105.
  if (strategy === SCHEDULE) {
    const { pipeline_config_strategy, variables_override, ...oldPolicy } = policy;
    newPolicy = {
      ...oldPolicy,
      schedules: [DEFAULT_SCHEDULE],
      type: PIPELINE_EXECUTION_SCHEDULE_POLICY,
    };
  } else {
    const { schedules, ...oldPolicy } = policy;
    const currentStrategy = policy.pipeline_config_strategy;
    // Preserve the object form (and its `apply_on_empty_pipeline`) when present, updating only its type.
    const newStrategy =
      currentStrategy && typeof currentStrategy === 'object'
        ? { ...currentStrategy, type: strategy }
        : strategy;
    newPolicy = {
      ...oldPolicy,
      pipeline_config_strategy: newStrategy,
      type: PIPELINE_EXECUTION_POLICY_TYPE,
      variables_override: policy.variables_override || DEFAULT_VARIABLES_OVERRIDE_STATE,
    };
  }

  return newPolicy;
};

/**
 * Validate policy actions and rules keys
 * @param policy
 * @returns {Object} errors object. If empty, policy is valid.
 */
export const validatePolicy = (policy) => {
  const error = {};

  const contentKeys = ['include'];
  const pipelineConfigStrategies = ['inject_policy', 'inject_ci', 'override_project_ci'];
  const hasInvalidPipelineConfigStrategy = (strategy) => {
    if (policy.type === PIPELINE_EXECUTION_POLICY_TYPE) {
      const strategyType = getPipelineConfigStrategyType(strategy);
      return !strategyType || !pipelineConfigStrategies.includes(strategyType);
    }
    return false;
  };

  if (
    hasInvalidKey(policy?.content || {}, contentKeys) ||
    hasInvalidPipelineConfigStrategy(policy.pipeline_config_strategy)
  ) {
    error.actions = true;
  }

  return error;
};

/**
 * Get policy type from manifest
 * @param {string} manifest policy
 * @returns {string} policy type
 */
const getPolicyType = (manifest) => {
  const pipelineExecutionPolicyType = PIPELINE_EXECUTION_POLICY_TYPE;

  try {
    const parsedYaml = safeLoad(manifest, { json: true });

    if (parsedYaml.type) {
      return parsedYaml.type;
    }

    if (parsedYaml[PIPELINE_EXECUTION_SCHEDULE_POLICY]) {
      return PIPELINE_EXECUTION_SCHEDULE_POLICY;
    }

    return pipelineExecutionPolicyType;
  } catch {
    return pipelineExecutionPolicyType;
  }
};

/**
 * Converts a security policy from yaml to an object
 * @param {String} manifest a security policy in yaml form
 * @param {String} type policy type
 * @returns {Object} security policy object and any errors
 */
export const createPolicyObject = (manifest, policyType) => {
  const type = policyType || getPolicyType(manifest);
  const policy = fromYaml({ manifest, type, addIds: false });
  const parsingError = validatePolicy(policy);
  return { policy, parsingError };
};

export const getInitialPolicy = (defaultPolicy, params = {}) => {
  const {
    type,
    compliance_framework_id: frameworkId,
    compliance_framework_name: frameworkName,
  } = params;
  const [file, project] = params?.path?.split('@') ?? [];

  if (!file || !project || !frameworkId || !frameworkName || !type) {
    return defaultPolicy;
  }

  const newPolicy = Object.assign(
    fromYaml({
      manifest: defaultPolicy,
      type: PIPELINE_EXECUTION_POLICY_TYPE,
      addIds: false,
    }),
    {
      type,
      pipeline_config_strategy: 'override_project_ci',
      policy_scope: { compliance_frameworks: [{ id: Number(frameworkId) }] },
      content: { include: [{ project, file }] },
      metadata: { compliance_pipeline_migration: true },
    },
  );

  return safeDump(newPolicy);
};
