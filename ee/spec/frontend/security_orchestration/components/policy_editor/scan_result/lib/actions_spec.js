import {
  ACTION_LISTBOX_ITEMS,
  APPROVER_TYPE_DICT,
  actionHasType,
  BOT_MESSAGE_TYPE,
  buildAction,
  createActionFromApprovers,
  REQUIRE_APPROVAL_TYPE,
  getDefaultHumanizedTemplate,
  isRoleApprover,
  mapYamlApproversActionsToSelectedApproverTypes,
  WARN_TYPE,
} from 'ee/security_orchestration/components/policy_editor/scan_result/lib/actions';
import { GROUP_TYPE, USER_TYPE, ROLE_TYPE } from 'ee/security_orchestration/constants';

const actionId = 'action_0';
jest.mock('lodash-es', () => ({
  ...jest.requireActual('lodash-es'),
  uniqueId: jest.fn().mockReturnValue(actionId),
}));

describe('actionHasType', () => {
  it.each`
    action                                              | type          | output
    ${{ key: 'value' }}                                 | ${ROLE_TYPE}  | ${false}
    ${{ [APPROVER_TYPE_DICT[ROLE_TYPE][0]]: 'value' }}  | ${USER_TYPE}  | ${false}
    ${{ [APPROVER_TYPE_DICT[USER_TYPE][0]]: 'value' }}  | ${GROUP_TYPE} | ${false}
    ${{ [APPROVER_TYPE_DICT[ROLE_TYPE][0]]: 'value' }}  | ${ROLE_TYPE}  | ${true}
    ${{ [APPROVER_TYPE_DICT[USER_TYPE][0]]: 'value' }}  | ${USER_TYPE}  | ${true}
    ${{ [APPROVER_TYPE_DICT[USER_TYPE][1]]: 'value' }}  | ${USER_TYPE}  | ${true}
    ${{ [APPROVER_TYPE_DICT[GROUP_TYPE][0]]: 'value' }} | ${GROUP_TYPE} | ${true}
    ${{ [APPROVER_TYPE_DICT[GROUP_TYPE][1]]: 'value' }} | ${GROUP_TYPE} | ${true}
  `('returns $output when action is $action and type is $type', ({ action, type, output }) => {
    expect(actionHasType(action, type)).toBe(output);
  });
});

describe('buildAction', () => {
  it('builds an approval action', () => {
    expect(buildAction(REQUIRE_APPROVAL_TYPE)).toEqual({
      approvals_required: 1,
      id: actionId,
      type: REQUIRE_APPROVAL_TYPE,
    });
  });

  it('builds a bot message action', () => {
    expect(buildAction(BOT_MESSAGE_TYPE)).toEqual({
      enabled: true,
      id: actionId,
      type: BOT_MESSAGE_TYPE,
    });
  });
});

describe('createActionFromApprovers', () => {
  it.each`
    userApprovers                   | groupApprovers
    ${[{ type: USER_TYPE, id: 1 }]} | ${[{ type: GROUP_TYPE, id: 2 }]}
    ${[1]}                          | ${[2]}
  `(
    'creates an action with all approvers $userApprovers and $groupApprovers',
    ({ userApprovers, groupApprovers }) => {
      const action = buildAction(REQUIRE_APPROVAL_TYPE);
      const approvers = {
        [USER_TYPE]: userApprovers,
        [ROLE_TYPE]: ['owner'],
        [GROUP_TYPE]: groupApprovers,
      };
      expect(createActionFromApprovers(action, approvers)).toEqual({
        ...action,
        group_approvers_ids: [2],
        role_approvers: ['owner'],
        user_approvers_ids: [1],
      });
    },
  );
});

describe('ACTION_LISTBOX_ITEMS', () => {
  it('contains three actions', () => {
    expect(ACTION_LISTBOX_ITEMS()).toEqual([
      { text: 'Require Approvers', value: 'require_approval' },
      { text: 'Send bot message', value: 'send_bot_message' },
      { value: WARN_TYPE, text: 'Warn in merge request' },
    ]);
  });
});

describe('getDefaultHumanizedTemplate', () => {
  it.each`
    numOfApproversRequired | isWarnType | expected
    ${0}                   | ${false}   | ${'%{requireStart}Require%{requireEnd} %{approvalsRequired} %{approvalStart}approvals%{approvalEnd} from:'}
    ${0}                   | ${true}    | ${'Developers may dismiss findings to proceed or%{requireStart}receive%{requireEnd} %{approvalsRequired} %{approvalStart}approvals%{approvalEnd} from:'}
  `(
    'creates the correct template when the number of approvers is $numOfApproversRequired and isWarnType is $isWarnType',
    ({ expected, isWarnType, numOfApproversRequired }) => {
      expect(getDefaultHumanizedTemplate(numOfApproversRequired, isWarnType)).toBe(expected);
    },
  );
});

describe('isRoleApprover', () => {
  it.each`
    baseAccessLevel                  | enabledPermissions                                              | expected
    ${null}                          | ${null}                                                         | ${false}
    ${null}                          | ${{ edges: [] }}                                                | ${false}
    ${{ stringValue: 'GUEST' }}      | ${{ edges: [] }}                                                | ${false}
    ${{ stringValue: 'REPORTER' }}   | ${{ edges: [] }}                                                | ${false}
    ${{ stringValue: 'DEVELOPER' }}  | ${{ edges: [] }}                                                | ${true}
    ${{ stringValue: 'MAINTAINER' }} | ${{ edges: [] }}                                                | ${true}
    ${{ stringValue: 'OWNER' }}      | ${{ edges: [] }}                                                | ${false}
    ${null}                          | ${{ edges: [{ node: { value: 'ADMIN_MERGE_REQUEST' } }] }}      | ${true}
    ${{ stringValue: 'GUEST' }}      | ${{ edges: [{ node: { value: 'ADMIN_MERGE_REQUEST' } }] }}      | ${true}
    ${{ stringValue: 'REPORTER' }}   | ${{ edges: [{ node: { value: 'ADMIN_MERGE_REQUEST' } }] }}      | ${true}
    ${{ stringValue: 'DEVELOPER' }}  | ${{ edges: [{ node: { value: 'ADMIN_MERGE_REQUEST' } }] }}      | ${true}
    ${{ stringValue: 'GUEST' }}      | ${{ edges: [{ node: { value: 'ADMIN_PROTECTED_BRANCHES' } }] }} | ${false}
    ${{ stringValue: 'REPORTER' }}   | ${{ edges: [{ node: { value: 'ADMIN_PROTECTED_BRANCHES' } }] }} | ${false}
  `(
    'returns $expected when baseAccessLevel is $baseAccessLevel and enabledPermissions is $enabledPermissions',
    ({ baseAccessLevel, enabledPermissions, expected }) => {
      expect(isRoleApprover({ baseAccessLevel, enabledPermissions })).toBe(expected);
    },
  );
});

describe('mapYamlApproversActionsToSelectedApproverTypes', () => {
  it.each`
    action                                                                   | output
    ${undefined}                                                             | ${['']}
    ${{ group_approvers_ids: [1, 2] }}                                       | ${[GROUP_TYPE]}
    ${{ group_approvers: [1, 2] }}                                           | ${[GROUP_TYPE]}
    ${{ user_approvers_ids: [1, 2] }}                                        | ${[USER_TYPE]}
    ${{ user_approvers: [1, 2] }}                                            | ${[USER_TYPE]}
    ${{ role_approvers: [1, 2] }}                                            | ${[ROLE_TYPE]}
    ${{ user_approvers_ids: [1, 2], user_approvers: [1, 2] }}                | ${[USER_TYPE]}
    ${{ user_approvers: [1, 2], role_approvers: [1], group_approvers: [1] }} | ${[ROLE_TYPE, USER_TYPE, GROUP_TYPE]}
  `('maps yaml format actions to component format', ({ action, output }) => {
    expect(mapYamlApproversActionsToSelectedApproverTypes(action)).toEqual(output);
  });
});
