import {
  BLOCK_BRANCH_MODIFICATION,
  BLOCK_GROUP_BRANCH_MODIFICATION,
  PREVENT_PUSHING_AND_FORCE_PUSHING,
  PREVENT_APPROVAL_BY_AUTHOR,
  PREVENT_APPROVAL_BY_COMMIT_AUTHOR,
  REMOVE_APPROVALS_WITH_NEW_COMMIT,
  REQUIRE_PASSWORD_TO_APPROVE,
  PREVENT_EDITING_APPROVAL_RULES,
} from './settings';

export * from './actions';
export * from './enforcement';
export * from './filters';
export * from './from_yaml';
export * from './rules';
export * from './settings';
export { policyToYaml } from './to_yaml';
export * from './vulnerability_states';

export const DEFAULT_SCAN_RESULT_POLICY = `approval_policy:
  - name: ''
    description: ''
    enabled: true
    enforcement_type: warn
    rules:
      - type: ''
    actions:
      - type: require_approval
        approvals_required: 1
      - type: send_bot_message
        enabled: true
    approval_settings:
      ${BLOCK_BRANCH_MODIFICATION}: true
      ${PREVENT_PUSHING_AND_FORCE_PUSHING}: true
      ${PREVENT_APPROVAL_BY_AUTHOR}: true
      ${PREVENT_APPROVAL_BY_COMMIT_AUTHOR}: true
      ${REMOVE_APPROVALS_WITH_NEW_COMMIT}: true
      ${PREVENT_EDITING_APPROVAL_RULES}: false
      ${REQUIRE_PASSWORD_TO_APPROVE}: false
    fallback_behavior:
      fail: closed
`;

export const DEFAULT_SCAN_RESULT_POLICY_WITH_SCOPE_WITH_GROUP_SETTINGS = `approval_policy:
  - name: ''
    description: ''
    enabled: true
    enforcement_type: warn
    policy_scope:
      projects:
        excluding: []
    rules:
      - type: ''
    actions:
      - type: require_approval
        approvals_required: 1
      - type: send_bot_message
        enabled: true
    approval_settings:
      ${BLOCK_BRANCH_MODIFICATION}: true
      ${BLOCK_GROUP_BRANCH_MODIFICATION}: true
      ${PREVENT_PUSHING_AND_FORCE_PUSHING}: true
      ${PREVENT_APPROVAL_BY_AUTHOR}: true
      ${PREVENT_APPROVAL_BY_COMMIT_AUTHOR}: true
      ${REMOVE_APPROVALS_WITH_NEW_COMMIT}: true
      ${PREVENT_EDITING_APPROVAL_RULES}: false
      ${REQUIRE_PASSWORD_TO_APPROVE}: false
    fallback_behavior:
      fail: closed
`;

export const getPolicyYaml = ({ isGroup }) => {
  return isGroup
    ? DEFAULT_SCAN_RESULT_POLICY_WITH_SCOPE_WITH_GROUP_SETTINGS
    : DEFAULT_SCAN_RESULT_POLICY;
};
