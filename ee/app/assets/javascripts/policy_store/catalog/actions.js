import { s__ } from '~/locale';
import { FIELD_TYPE_MULTI_BADGE, FIELD_TYPE_TEXT } from '../components/editor/constants';
import { CATEGORY_ENFORCEMENT } from './categories';

// Actions a policy can take when its rules match. `id` is persisted as the action object's
// `type` and read by EE::Ci::ProcessBuildService#enforce_policy_actions, so it is the wire value.
//
// There is deliberately no `warn` action: warn is an enforcement *mode*, and `block` behaves
// differently depending on it. See https://gitlab.com/gitlab-org/gitlab/-/issues/607341.
export const ACTION_BLOCK = 'block';
export const ACTION_REQUIRE_APPROVAL = 'require_approval';

export const ACTIONS = [
  {
    id: ACTION_BLOCK,
    category: CATEGORY_ENFORCEMENT,
    label: s__('PolicyStore|Block'),
    description: s__('PolicyStore|Block the action from proceeding'),
    icon: 'cancel',
    fields: [
      {
        key: 'blockMessage',
        type: FIELD_TYPE_TEXT,
        label: s__('PolicyStore|Block message'),
        placeholder: s__('PolicyStore|Message shown when the action is blocked'),
      },
      {
        key: 'overrideGroups',
        type: FIELD_TYPE_TEXT,
        label: s__('PolicyStore|Override groups'),
        placeholder: s__('PolicyStore|e.g. security-leads, engineering-leads'),
      },
    ],
  },
  {
    id: ACTION_REQUIRE_APPROVAL,
    category: CATEGORY_ENFORCEMENT,
    label: s__('PolicyStore|Require approval'),
    description: s__('PolicyStore|Require additional approvals before proceeding'),
    icon: 'approval',
    fields: [
      {
        key: 'roles',
        type: FIELD_TYPE_MULTI_BADGE,
        label: s__('PolicyStore|Role approvers'),
        options: [
          { id: 'developer', label: s__('PolicyStore|Developer') },
          { id: 'maintainer', label: s__('PolicyStore|Maintainer') },
          { id: 'owner', label: s__('PolicyStore|Owner') },
        ],
      },
    ],
  },
];
