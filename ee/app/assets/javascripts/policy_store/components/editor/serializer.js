import { getIdFromGraphQLId, convertToGraphQLId } from '~/graphql_shared/utils';
import { TYPENAME_PROJECT } from '~/graphql_shared/constants';
import { RULE_CUSTOM } from '../../catalog/rules';
import { SCOPE_ALL, SCOPE_SPECIFIC } from './constants';

// Translates between the editor's form state and the shape the Policy Store API persists.

/**
 * Serializes one selected rule into the `{ type, value }` pair the API persists.
 *
 * For the Rego rule `value` is the program itself; for typed rules `value` is
 * the rule's configuration object.
 *
 * @param {string} id - Catalog id of the rule; persisted as the rule's `type`.
 * @param {Object} config - The rule's configuration from the form state.
 * @returns {{ type: string, value: (string|Object) }} The rule as persisted.
 */
const serializeRule = (id, config) =>
  id === RULE_CUSTOM
    ? { type: RULE_CUSTOM, value: config.policy || '' }
    : { type: id, value: { ...config } };

/**
 * Reverses serializeRule: reads one persisted rule into a `[id, config]` entry
 * of the form state.
 *
 * @param {{ type: string, value: (string|Object) }} rule - The rule as persisted.
 * @returns {[string, Object]} The rule's catalog id and its form configuration.
 */
const deserializeRule = ({ type, value }) =>
  type === RULE_CUSTOM ? [type, { policy: value || '' }] : [type, { ...value }];

/**
 * Serializes the editor's form state into the policy data the API persists.
 *
 * The shapes here follow the write endpoints' declared params exactly —
 * anything else is dropped by the API on write:
 * - The trigger is persisted as `trigger_type` (the endpoints never adopted
 *   the prototype's `trigger_id` name).
 * - Rules and actions are `{ type, value }` pairs; configs live under `value`.
 * - There is no `trigger_config` param, and the only shipped trigger has no
 *   config fields, so trigger config is not sent.
 *
 * @param {Object} [formState] - The editor's form state.
 * @param {string|null} [formState.trigger] - Selected trigger id.
 * @param {string[]} [formState.rules] - Selected rule ids.
 * @param {Object} [formState.ruleConfigs] - Rule configurations keyed by rule id.
 * @param {string[]} [formState.actions] - Selected action ids.
 * @param {Object} [formState.actionConfigs] - Action configurations keyed by action id.
 * @returns {{ trigger_type: (string|null), rules: Object[], actions: Object[] }}
 *   The policy data as persisted.
 */
export const serializePolicyData = ({
  trigger = null,
  rules = [],
  ruleConfigs = {},
  actions = [],
  actionConfigs = {},
} = {}) => ({
  trigger_type: trigger,
  rules: rules.map((id) => serializeRule(id, ruleConfigs[id] || {})),
  actions: actions.map((id) => ({ type: id, value: { ...(actionConfigs[id] || {}) } })),
});

const firstPerType = (entries) => {
  const seen = new Map();

  entries.forEach(([type, config]) => {
    if (!seen.has(type)) seen.set(type, config);
  });

  return [...seen.entries()];
};

/**
 * Reverses serializePolicyData: reads persisted policy data into the editor's
 * form state.
 *
 * @param {Object} [policyData] - The policy data as persisted.
 * @param {string} [policyData.trigger_type] - The trigger's catalog id.
 * @param {Object[]} [policyData.rules] - Rules as `{ type, value }` pairs.
 * @param {Object[]} [policyData.actions] - Actions as `{ type, value }` pairs.
 * @returns {Object} The editor's form state: selected ids under `trigger`, `rules`
 *   and `actions`, their configurations under `triggerConfig`, `ruleConfigs` and
 *   `actionConfigs`.
 */
export const deserializePolicyData = ({ trigger_type: triggerType, rules, actions } = {}) => {
  const ruleEntries = firstPerType((rules || []).map(deserializeRule));
  const actionEntries = firstPerType(
    (actions || []).map(({ type, value }) => [type, { ...value }]),
  );

  return {
    trigger: triggerType || null,
    triggerConfig: {},
    rules: ruleEntries.map(([type]) => type),
    ruleConfigs: Object.fromEntries(ruleEntries),
    actions: actionEntries.map(([type]) => type),
    actionConfigs: Object.fromEntries(actionEntries),
  };
};

/**
 * @returns {Object} The empty form state for a policy that has nothing selected yet.
 */
export const emptyPolicyData = () => ({
  trigger: null,
  triggerConfig: {},
  rules: [],
  ruleConfigs: {},
  actions: [],
  actionConfigs: {},
});

const scopedProjectIds = (projects) => projects.map(({ id }) => getIdFromGraphQLId(id));

/**
 * Serializes the Scope step's state into the `policy_scope` hash the API
 * persists. The two shapes are unrelated: the Scope step holds GraphQL project
 * nodes (`gid://` ids) from the projects dropdown, while the store persists
 * criteria as plain arrays of numeric ids and rejects any other shape. "All
 * projects" with no exclusions serializes to an empty hash, which the store
 * treats as applying to every project.
 *
 * @param {Object} [scope] - The Scope step's state.
 * @param {string} [scope.mode] - SCOPE_ALL or SCOPE_SPECIFIC.
 * @param {Object[]} [scope.projects] - Included projects, with GraphQL ids.
 * @param {Object[]} [scope.exclusions] - Excluded projects, with GraphQL ids.
 * @returns {Object} The policy scope as persisted.
 */
export const serializeScope = ({ mode = SCOPE_ALL, projects = [], exclusions = [] } = {}) => {
  const projectScope = {};

  if (mode === SCOPE_SPECIFIC && projects.length) {
    projectScope.including = scopedProjectIds(projects);
  }

  if (exclusions.length) {
    projectScope.excluding = scopedProjectIds(exclusions);
  }

  return Object.keys(projectScope).length ? { projects: projectScope } : {};
};

// A stored criterion entry is an id or an `{ id }` hash, and the excluding list
// can also carry `{ type: 'personal' | 'archived' }` entries with no id. Those
// typed entries have no wizard representation: they survive a save only while
// the Scope step is untouched (the scopeChanged guard skips policy_scope on
// update), and editing the scope rebuilds policy_scope from the wizard's
// project-only state and drops them. Accepted gap until the Scope step can
// author typed exclusions.
const scopedIds = (criterion) =>
  (Array.isArray(criterion) ? criterion : [])
    .map((entry) => (entry && typeof entry === 'object' ? entry.id : entry))
    .filter((id) => id != null);

const toScopedProject = (id) => ({ id: convertToGraphQLId(TYPENAME_PROJECT, id) });

/**
 * Reverses serializeScope: reads a persisted `policy_scope` into the Scope
 * step's state. Only project ids survive the round trip, so the projects come
 * back as id-only stubs the project dropdowns resolve.
 *
 * @param {Object} [policyScope] - The policy scope as persisted.
 * @returns {{ mode: string, projects: Object[], exclusions: Object[] }}
 */
export const deserializeScope = (policyScope) => {
  const including = scopedIds(policyScope?.projects?.including);
  const excluding = scopedIds(policyScope?.projects?.excluding);

  return {
    mode: including.length ? SCOPE_SPECIFIC : SCOPE_ALL,
    projects: including.map(toScopedProject),
    exclusions: excluding.map(toScopedProject),
  };
};

/**
 * Serializes everything the wizard edits into the params the create and update
 * endpoints accept.
 *
 * @param {Object} wizardState
 * @param {string} wizardState.name
 * @param {string} wizardState.description
 * @param {string} wizardState.mode - Enforcement mode.
 * @param {Object} wizardState.scope - The Scope step's state.
 * @param {Object} wizardState.policyData - The Build step's form state.
 * @returns {Object} The request params for the Policy Store write endpoints.
 */
export const serializePolicyParams = ({ name, description, mode, scope, policyData }) => ({
  name,
  description,
  mode,
  policy_scope: serializeScope(scope),
  ...serializePolicyData(policyData),
});
