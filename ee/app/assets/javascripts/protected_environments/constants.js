import { s__ } from '~/locale';

export const INHERITED_GROUPS = 1;
export const NON_INHERITED_GROUPS = 0;
export const GROUP_INHERITANCE_KEY = 'group_inheritance_type';
export const DEPLOYER_RULE_KEY = 'deploy_access_levels';
export const APPROVER_RULE_KEY = 'approval_rules';
export const RULE_KEYS = [DEPLOYER_RULE_KEY, APPROVER_RULE_KEY];

export const ACCESS_LEVELS = {
  DEPLOY: 'deploy_access_levels',
};

export const LEVEL_TYPES = {
  ROLE: 'role',
  USER: 'user',
  GROUP: 'group',
};

export const DEPLOYER_FIELDS = [
  {
    key: 'deployers',
    label: s__('ProtectedEnvironments|Allowed to deploy'),
    tdClass: '@md/panel:gl-w-3/10',
  },
  {
    key: 'users',
    label: s__('ProtectedEnvironments|Users'),
  },
  {
    key: 'actions',
    label: '',
    tdClass: 'gl-text-right',
  },
];

export const APPROVER_FIELDS = [
  {
    key: 'approvers',
    label: s__('ProtectedEnvironments|Approvers'),
    tdClass: '@md/panel:gl-w-3/10',
  },
  {
    key: 'users',
    label: s__('ProtectedEnvironments|Users'),
  },
  {
    key: 'approvals',
    label: s__('ProtectedEnvironments|Approvals required'),
  },
  {
    key: 'inheritance',
    label: s__('ProtectedEnvironments|Enable group inheritance'),
  },
  {
    key: 'actions',
    label: '',
    tdClass: 'gl-text-right',
  },
];
