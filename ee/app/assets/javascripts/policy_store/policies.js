import Api from 'ee/api';
import { presentable } from './catalog/catalogs';
import { TRIGGERS } from './catalog/triggers';

// Same resolution the wizard uses: the local catalog supplies the label for ids
// it knows, the API-provided name covers newer triggers, the raw id is the last
// resort. Keeps the list and the editor rendering the same trigger the same way.
const triggerLabel = (triggerType, remoteTriggers) =>
  presentable(remoteTriggers.find(({ id }) => id === triggerType) ?? { id: triggerType }, TRIGGERS)
    .label;

// A stored criterion is a plain array of ids or `{ id }` hashes.
const scopedProjectsCount = (policyScope) => {
  const including = policyScope?.projects?.including;

  return Array.isArray(including) ? including.length : 0;
};

// The list renders `type`, `status` and `scopedProjectsCount` columns on top
// of the policy as the API returns it; the editor reads the raw fields back
// through deserializePolicyData and deserializeScope.
const toListPolicy = (policy, remoteTriggers) => ({
  ...policy,
  type: triggerLabel(policy.trigger_type, remoteTriggers),
  status: policy.lifecycle_state,
  scopedProjectsCount: scopedProjectsCount(policy.policy_scope),
});

// The triggers catalog only affects labels, so its failure degrades them
// instead of failing the policy fetch.
const fetchRemoteTriggers = () =>
  Api.getPolicyTriggers()
    .then(({ data: triggers }) => triggers.filter((trigger) => trigger?.id))
    .catch(() => []);

/**
 * Fetches the organization's policies from the Policy Store API, mapped for the
 * list and the editor. Rejects with the request error on failure.
 *
 * @param {string|number} organizationId
 * @returns {Promise<Array>}
 */
export const fetchPolicies = async (organizationId) => {
  const [{ data }, remoteTriggers] = await Promise.all([
    Api.getPolicyStorePolicies(organizationId),
    fetchRemoteTriggers(),
  ]);

  return data.map((policy) => toListPolicy(policy, remoteTriggers));
};

/**
 * Fetches one policy from the Policy Store API, mapped the same way as the
 * list so the editor can read it back. Rejects with the request error on
 * failure, including a 404 for a policy the organization does not have.
 *
 * @param {string|number} organizationId
 * @param {string|number} policyId
 * @returns {Promise<Object>}
 */
export const fetchPolicy = async (organizationId, policyId) => {
  const [{ data }, remoteTriggers] = await Promise.all([
    Api.getPolicyStorePolicy(organizationId, policyId),
    fetchRemoteTriggers(),
  ]);

  return toListPolicy(data, remoteTriggers);
};

/**
 * Creates a policy through the Policy Store API. Rejects with the request
 * error on failure, including a 400 when the params fail validation.
 *
 * @param {string|number} organizationId
 * @param {Object} params - Params from serializePolicyParams.
 * @returns {Promise<Object>} The created policy, mapped like the list.
 */
export const createPolicy = async (organizationId, params) => {
  const [{ data }, remoteTriggers] = await Promise.all([
    Api.createPolicyStorePolicy(organizationId, params),
    fetchRemoteTriggers(),
  ]);

  return toListPolicy(data, remoteTriggers);
};

/**
 * Updates one policy through the Policy Store API. Rejects with the request
 * error on failure, including a 400 when the params fail validation.
 *
 * @param {string|number} organizationId
 * @param {string|number} policyId
 * @param {Object} params - Params from serializePolicyParams.
 * @returns {Promise<Object>} The updated policy, mapped like the list.
 */
export const updatePolicy = async (organizationId, policyId, params) => {
  const [{ data }, remoteTriggers] = await Promise.all([
    Api.updatePolicyStorePolicy(organizationId, policyId, params),
    fetchRemoteTriggers(),
  ]);

  return toListPolicy(data, remoteTriggers);
};

/**
 * Deletes one policy through the Policy Store API. Rejects with the request
 * error on failure.
 *
 * @param {string|number} organizationId
 * @param {string|number} policyId
 * @returns {Promise}
 */
export const deletePolicy = (organizationId, policyId) =>
  Api.deletePolicyStorePolicy(organizationId, policyId);
