import { safeDump } from 'js-yaml';

const cleanConfig = (config) => {
  const cleaned = {};
  for (const [key, val] of Object.entries(config)) {
    if (val === '' || val == null) continue;
    if (Array.isArray(val)) {
      if (val.length) cleaned[key] = val;
      continue;
    }
    if (typeof val === 'object') {
      const sub = cleanConfig(val);
      if (Object.keys(sub).length) cleaned[key] = sub;
      continue;
    }
    cleaned[key] = val;
  }
  return cleaned;
};

// `require_approval` parsing collapses YAML's group_approvers/user_approvers/
// approvals_required/request_message into single UI fields. Reverse that here
// so the emitted YAML matches the policy schema. '@' prefix distinguishes
// users from groups in the comma-separated approverGroups text.
const transformRequireApproval = (config) => {
  const out = {};
  if (config.approverGroups) {
    const groups = [];
    const users = [];
    config.approverGroups
      .split(',')
      .map((s) => s.trim())
      .filter(Boolean)
      .forEach((entry) => {
        if (entry.startsWith('@')) users.push(entry.slice(1));
        else groups.push(entry);
      });
    if (groups.length) out.group_approvers = groups;
    if (users.length) out.user_approvers = users;
  }
  if (config.approvalCount) {
    const parsed = Number.parseInt(config.approvalCount, 10);
    if (Number.isFinite(parsed)) out.approvals_required = parsed;
  }
  if (config.requestMessage) out.request_message = config.requestMessage;
  return out;
};

const ACTION_TRANSFORMS = {
  require_approval: transformRequireApproval,
};

const itemsWithConfigs = (types, configs, transforms = {}) =>
  types.map((type) => {
    const cleaned = cleanConfig(configs[type] || {});
    const transformed = transforms[type] ? transforms[type](cleaned) : cleaned;
    return { type, ...transformed };
  });

export const buildPolicyObject = ({
  policyName,
  policyDescription,
  scope,
  triggers = [],
  rules = [],
  actions = [],
  triggerConfigs = {},
  ruleConfigs = {},
  actionConfigs = {},
}) => {
  const policy = {
    name: policyName,
    scope: scope || 'all',
  };
  if (policyDescription) policy.description = policyDescription;
  if (triggers.length) policy.triggers = itemsWithConfigs(triggers, triggerConfigs);
  if (rules.length) policy.rules = itemsWithConfigs(rules, ruleConfigs);
  if (actions.length) policy.actions = itemsWithConfigs(actions, actionConfigs, ACTION_TRANSFORMS);
  return policy;
};

export const buildPolicyYaml = (state) => safeDump(buildPolicyObject(state), { lineWidth: -1 });
