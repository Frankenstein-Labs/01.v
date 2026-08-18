import { uniqueId, isNumber } from 'lodash-es';
import { n__, s__ } from '~/locale';
import { GROUP_TYPE, ROLE_TYPE, USER_TYPE } from 'ee/security_orchestration/constants';
import { mapToListboxItems } from 'ee/security_orchestration/utils';

export const APPROVER_TYPE_DICT = {
  [GROUP_TYPE]: ['group_approvers', 'group_approvers_ids'],
  [ROLE_TYPE]: ['role_approvers'],
  [USER_TYPE]: ['user_approvers', 'user_approvers_ids'],
};

export const ADD_APPROVER_LABEL = s__('SecurityOrchestration|Add new approver');

export const APPROVER_TYPE_LIST_ITEMS = [
  { text: s__('SecurityOrchestration|Roles'), value: ROLE_TYPE },
  { text: s__('SecurityOrchestration|Individual users'), value: USER_TYPE },
  { text: s__('SecurityOrchestration|Groups'), value: GROUP_TYPE },
];

const mapIds = (approvers, namespaceType) =>
  approvers
    .filter((approver) => isNumber(approver) || approver.type === namespaceType)
    .map((item) => (isNumber(item) ? item : item.id));

const userIds = (approvers) => {
  return mapIds(approvers, USER_TYPE);
};

const groupIds = (approvers) => {
  return mapIds(approvers, GROUP_TYPE);
};

export const removeAvailableApproverType = (array, type) =>
  array.filter(({ value }) => value !== type);

/*
  Convert approvers into yaml fields (user_approvers, users_approvers_ids) in relation to action.
*/
export const createActionFromApprovers = ({ id, type, approvals_required }, approvers) => {
  const newAction = { id, type, approvals_required };

  if (approvers[USER_TYPE]) {
    newAction.user_approvers_ids = userIds(approvers[USER_TYPE]);
  }

  if (approvers[GROUP_TYPE]) {
    newAction.group_approvers_ids = groupIds(approvers[GROUP_TYPE]);
  }

  if (approvers[ROLE_TYPE]) {
    newAction.role_approvers = approvers[ROLE_TYPE];
  }

  return newAction;
};

export const actionHasType = (action, type) => {
  return Object.keys(action).some((k) => APPROVER_TYPE_DICT[type].includes(k));
};

export const WARN_TEMPLATE = s__(
  'SecurityOrchestration|%{requireStart}Warn users with a bot comment%{requireEnd} and select approvers. The approvers are required unless developers dismiss the warn mode policy. After dismissal, approvers become optional.',
);

export const getDefaultHumanizedTemplate = (numOfApproversRequired, isWarnType) => {
  if (isWarnType) {
    return n__(
      'Developers may dismiss findings to proceed or%{requireStart}receive%{requireEnd} %{approvalsRequired} %{approvalStart}approval%{approvalEnd} from:',
      'Developers may dismiss findings to proceed or%{requireStart}receive%{requireEnd} %{approvalsRequired} %{approvalStart}approvals%{approvalEnd} from:',
      numOfApproversRequired,
    );
  }

  return n__(
    '%{requireStart}Require%{requireEnd} %{approvalsRequired} %{approvalStart}approval%{approvalEnd} from:',
    '%{requireStart}Require%{requireEnd} %{approvalsRequired} %{approvalStart}approvals%{approvalEnd} from:',
    numOfApproversRequired,
  );
};

export const DEFAULT_APPROVER_DROPDOWN_TEXT = s__('SecurityOrchestration|Choose approver type');

export const REQUIRE_APPROVAL_TYPE = 'require_approval';

export const BOT_MESSAGE_TYPE = 'send_bot_message';

export const WARN_TYPE = 'warn';

export const buildApprovalAction = (approvalsRequired = 1) => {
  return {
    type: REQUIRE_APPROVAL_TYPE,
    approvals_required: approvalsRequired,
    id: uniqueId('action_'),
  };
};

export const buildBotMessageAction = () => {
  return { type: BOT_MESSAGE_TYPE, enabled: true, id: uniqueId('action_') };
};

export const buildAction = (type) => {
  switch (type) {
    case REQUIRE_APPROVAL_TYPE:
      return buildApprovalAction();
    case BOT_MESSAGE_TYPE:
    default:
      return buildBotMessageAction();
  }
};

export const WARN_TYPE_TEXT = s__('SecurityOrchestration|Warn in merge request');

export const ACTION_OPTIONS = {
  [REQUIRE_APPROVAL_TYPE]: s__('SecurityOrchestration|Require Approvers'),
  [BOT_MESSAGE_TYPE]: s__('SecurityOrchestration|Send bot message'),
  [WARN_TYPE]: WARN_TYPE_TEXT,
};

export const ACTION_LISTBOX_ITEMS = () => {
  return mapToListboxItems(ACTION_OPTIONS);
};

export const DISABLED_BOT_MESSAGE_ACTION = { ...buildAction(BOT_MESSAGE_TYPE), enabled: false };

export const ROLE_PERMISSION_TO_APPROVE_MRS = 'ADMIN_MERGE_REQUEST';

const BASE_ACCESS_LEVELS_WITH_APPROVAL = ['MAINTAINER', 'DEVELOPER'];

export const isRoleApprover = ({ baseAccessLevel, enabledPermissions }) =>
  enabledPermissions?.edges.some(
    ({ node = {} }) => node.value === ROLE_PERMISSION_TO_APPROVE_MRS,
  ) || BASE_ACCESS_LEVELS_WITH_APPROVAL.includes(baseAccessLevel?.stringValue);

/**
 * Map selected approver ids or names to selected types
 * @param action approver action
 * @returns {Array} flat array of selected types
 */
export const mapYamlApproversActionsToSelectedApproverTypes = (action = {}) => {
  const hasRoleApprovers = 'role_approvers' in action;
  const hasUserApprovers = 'user_approvers_ids' in action || 'user_approvers' in action;
  const hasGroupApprovers = 'group_approvers_ids' in action || 'group_approvers' in action;

  const uiStates = [];

  if (hasRoleApprovers) uiStates.push(ROLE_TYPE);
  if (hasUserApprovers) uiStates.push(USER_TYPE);
  if (hasGroupApprovers) uiStates.push(GROUP_TYPE);
  if (uiStates.length === 0) uiStates.push('');

  return uiStates;
};
