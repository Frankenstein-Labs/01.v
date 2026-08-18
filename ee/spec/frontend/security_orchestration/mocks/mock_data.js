import { convertToGraphQLId } from '~/graphql_shared/utils';
import { TYPENAME_GROUP, TYPENAME_PROJECT } from '~/graphql_shared/constants';
import {
  APPROVAL_POLICY_TYPE,
  DEFAULT_SKIP_SI_CONFIGURATION,
  SCAN_EXECUTION_POLICY_TYPE,
} from 'ee/security_orchestration/components/constants';

export const actionId = 'action_0';
export const ruleId = 'rule_0';

export const invalidYaml = 'variable: true:';

export const unsupportedManifest = `---
name: This policy has an unsupported attribute
enabled: false
UNSUPPORTED: ATTRIBUTE
rules:
- type: pipeline
  branches:
  - main
actions:
- scan: sast
`;

export const unsupportedManifestObject = {
  name: 'This policy has an unsupported attribute',
  enabled: false,
  UNSUPPORTED: 'ATTRIBUTE',
  rules: [{ type: 'pipeline', branches: ['main'], id: ruleId }],
  actions: [{ scan: 'sast', id: actionId }],
};

export const unsupportedManifestObjectScanExecution = {
  name: 'This policy has an unsupported attribute',
  enabled: false,
  UNSUPPORTED: 'ATTRIBUTE',
  rules: [{ type: 'pipeline', branches: ['main'], id: ruleId }],
  actions: [{ scan: 'sast', id: actionId }],
  type: SCAN_EXECUTION_POLICY_TYPE,
};

export const invalidPolicyRules = {
  name: 'This policy has invalid properties',
  enabled: true,
  rules: [{ type: 'pipeline', branches: ['main'], id: ruleId, branch_type: 'invalid' }],
  actions: [{ scan: 'sast', id: actionId }],
};
export const invalidPolicyActions = {
  name: 'This policy has invalid properties',
  enabled: true,
  rules: [{ type: 'pipeline', branches: ['main'], id: ruleId }],
  actions: [{ scan: 'invalid', id: actionId }],
};

export const RUNNER_TAG_LIST_MOCK = [
  {
    id: 'gid://gitlab/Ci::Runner/1',
    tagList: ['macos', 'linux', 'docker'],
  },
  {
    id: 'gid://gitlab/Ci::Runner/2',
    tagList: ['backup', 'linux', 'development'],
  },
];

export const APPROVAL_POLICY_DEFAULT_POLICY = {
  type: APPROVAL_POLICY_TYPE,
  name: '',
  description: '',
  enabled: true,
  enforcement_type: 'warn',
  rules: [{ type: '', id: 'rule_2' }],
  actions: [
    { type: 'require_approval', approvals_required: 1, id: 'action_0' },
    { type: 'send_bot_message', enabled: true, id: 'action_1' },
  ],
  approval_settings: {
    block_branch_modification: true,
    prevent_pushing_and_force_pushing: true,
    prevent_approval_by_author: true,
    prevent_approval_by_commit_author: true,
    remove_approvals_with_new_commit: true,
    prevent_editing_approval_rules: false,
    require_password_to_approve: false,
  },
  fallback_behavior: { fail: 'closed' },
};

export const APPROVAL_POLICY_DEFAULT_POLICY_WITH_SCOPE_WITH_GROUP_SETTINGS = {
  ...APPROVAL_POLICY_DEFAULT_POLICY,
  policy_scope: { projects: { excluding: [] } },
  approval_settings: {
    ...APPROVAL_POLICY_DEFAULT_POLICY.approval_settings,
    block_group_branch_modification: true,
  },
};

export const SCAN_EXECUTION_DEFAULT_POLICY = {
  type: SCAN_EXECUTION_POLICY_TYPE,
  name: '',
  description: '',
  enabled: true,
  actions: [
    {
      id: 'action_0',
      scan: 'secret_detection',
      template: 'latest',
      variables: { SECURE_ENABLE_LOCAL_CONFIGURATION: 'false' },
    },
  ],
  rules: [
    { type: 'pipeline', branch_type: 'default', id: 'rule_1' },
    {
      id: 'rule_2',
      type: 'pipeline',
      branch_type: 'target_default',
      pipeline_sources: { including: ['merge_request_event'] },
    },
  ],
  skip_ci: DEFAULT_SKIP_SI_CONFIGURATION,
};

export const SCAN_EXECUTION_DEFAULT_POLICY_WITH_SCOPE = {
  ...SCAN_EXECUTION_DEFAULT_POLICY,
  policy_scope: { projects: { excluding: [] } },
};

export const ASSIGNED_POLICY_PROJECT = {
  branch: 'main',
  fullPath: 'path/to/existing-project',
};

export const generateMockProjects = (ids) =>
  ids.map((id) => ({
    id: convertToGraphQLId(TYPENAME_PROJECT, id),
    name: `${id}`,
    fullPath: `project-${id}-full-path`,
    repository: { rootRef: 'main' },
    group: { id: convertToGraphQLId(TYPENAME_GROUP, id) },
  }));

export const generateMockGroups = (ids) =>
  ids.map((id) => ({
    id: convertToGraphQLId(TYPENAME_GROUP, id),
    name: `${id}`,
    fullPath: `group-${id}-full-path`,
  }));

export const createMockGroup = (id) => {
  return { id, full_name: `Group-${id}`, full_path: `group-${id}` };
};

export const createMockGroups = (length = 2) =>
  Array.from({ length }, (_, i) => i + 1).map((id) => ({
    id,
    name: `Group-${id}`,
    fullName: `Group-${id}`,
    fullPath: `group full path ${id}`,
    avatarUrl: `group avatar url ${id}`,
  }));
