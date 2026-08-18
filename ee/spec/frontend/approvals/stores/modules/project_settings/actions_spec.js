import MockAdapter from 'axios-mock-adapter';
import {
  mapApprovalRuleRequest,
  mapApprovalSettingsResponse,
  mapApprovalRuleResponse,
} from 'ee/approvals/mappers';
import * as types from 'ee/approvals/stores/modules/base/mutation_types';
import * as actions from 'ee/approvals/stores/modules/project_settings/actions';
import testAction from 'helpers/vuex_action_helper';
import { createAlert } from '~/alert';
import axios from '~/lib/utils/axios_utils';
import { HTTP_STATUS_INTERNAL_SERVER_ERROR, HTTP_STATUS_OK } from '~/lib/utils/http_status';

jest.mock('~/alert');

const TEST_PROJECT_ID = 9;
const TEST_RULE_ID = 7;
const TEST_RULE = {
  id: 1,
  name: 'Doros',
  approvalsRequired: 3,
  groups: [{ id: 1 }],
  users: [{ id: 1 }, { id: 1 }],
};
const TEST_RULE_REQUEST = {
  name: 'Lorem',
  approvalsRequired: 1,
  groups: [7],
  users: [8, 9],
};
const TEST_RULE_RESPONSE = {
  id: 7,
  name: 'Ipsum',
  approvals_required: 2,
  approvers: [{ id: 7 }, { id: 8 }, { id: 9 }],
  groups: [{ id: 4 }],
  users: [{ id: 7 }, { id: 8 }],
};
const TEST_RULES_PATH = 'projects/9/approval_rules';

const mockHeaders = {
  'X-Next-Page': 2,
  'X-Total': 20,
};

describe('EE approvals project settings module actions', () => {
  let state;
  let mock;

  beforeEach(() => {
    state = {
      settings: {
        projectId: TEST_PROJECT_ID,
        settingsPath: TEST_RULES_PATH,
        rulesPath: TEST_RULES_PATH,
      },
    };
    mock = new MockAdapter(axios);
  });

  afterEach(() => {
    mock.restore();
  });

  describe('drawer', () => {
    it('openCreateDrawer', () => {
      return testAction(
        actions.openCreateDrawer,
        TEST_RULE_RESPONSE,
        {},
        [
          { type: types.SET_DRAWER_OPEN, payload: true },
          { type: types.SET_EDIT_RULE, payload: TEST_RULE_RESPONSE },
        ],
        [],
      );
    });

    it('closeCreateDrawer', () => {
      return testAction(
        actions.closeCreateDrawer,
        null,
        {},
        [
          { type: types.SET_DRAWER_OPEN, payload: false },
          { type: types.SET_EDIT_RULE, payload: null },
        ],
        [],
      );
    });
  });

  describe('requestRules', () => {
    it('sets loading', () => {
      return testAction(
        actions.requestRules,
        null,
        {},
        [{ type: types.SET_LOADING, payload: true }],
        [],
      );
    });
  });

  describe('receiveRulesSuccess', () => {
    it('sets rules', () => {
      const settings = [TEST_RULE];
      const pagination = { total: 1 };

      return testAction(
        actions.receiveRulesSuccess,
        { approvalSettings: settings, pagination },
        {},
        [
          { type: types.SET_APPROVAL_SETTINGS, payload: { ...settings, isPagination: true } },
          { type: types.SET_RULES_PAGINATION, payload: pagination },
          { type: types.SET_LOADING, payload: false },
        ],
        [],
      );
    });
  });

  describe('receiveRulesError', () => {
    it('creates an alert', () => {
      expect(createAlert).not.toHaveBeenCalled();

      actions.receiveRulesError();

      expect(createAlert).toHaveBeenCalledTimes(1);
      expect(createAlert).toHaveBeenCalledWith({
        message: expect.stringMatching('error occurred'),
      });
    });
  });

  describe('setRulesFilter', () => {
    it('sets rules', () => {
      const rules = ['test'];

      return testAction(
        actions.setRulesFilter,
        rules,
        {},
        [{ type: types.SET_RULES_FILTER, payload: rules }],
        [],
      );
    });
  });

  describe('setRules', () => {
    it('replaces rules and sets pagination', () => {
      const rules = [TEST_RULE];

      return testAction(
        actions.setRules,
        { rules, totalRules: 1 },
        {},
        [
          { type: types.SET_RULES, payload: rules },
          { type: types.SET_RULES_PAGINATION, payload: { total: 1 } },
        ],
        [],
      );
    });
  });

  describe('updateRules', () => {
    beforeEach(() => {
      state = {
        ...state,
        approvals: {
          rules: [TEST_RULE_RESPONSE],
          rulesPagination: {
            nextPage: 1,
            total: 20,
          },
        },
      };
    });

    describe('when rule exists', () => {
      it('updates rule', () => {
        const updatedRule = { ...TEST_RULE_RESPONSE, name: 'Updated name' };

        return testAction(
          actions.updateRules,
          updatedRule,
          state,
          [],
          [
            {
              type: 'setRules',
              payload: {
                rules: [mapApprovalRuleResponse(updatedRule)],
                totalRules: 20,
              },
            },
          ],
        );
      });
    });

    describe('when new rule added', () => {
      it('adds new rule in the rules list and increase pagination `total` property', () => {
        return testAction(
          actions.updateRules,
          TEST_RULE,
          state,
          [],
          [
            {
              type: 'setRules',
              payload: {
                rules: [TEST_RULE_RESPONSE, mapApprovalRuleResponse(TEST_RULE)],
                totalRules: 21,
              },
            },
          ],
        );
      });
    });

    describe('when any_approver placeholder exists', () => {
      it('replaces the placeholder rule without increasing total count', () => {
        const placeholderRule = {
          id: null,
          name: 'All Members',
          ruleType: 'any_approver',
          approvalsRequired: 0,
        };
        const newAnyApproverRule = {
          id: 20,
          name: 'All Members',
          rule_type: 'any_approver',
          approvals_required: 1,
        };

        state.approvals.rules = [placeholderRule];

        return testAction(
          actions.updateRules,
          newAnyApproverRule,
          state,
          [],
          [
            {
              type: 'setRules',
              payload: {
                rules: [mapApprovalRuleResponse(newAnyApproverRule)],
                totalRules: 20,
              },
            },
          ],
        );
      });
    });
  });

  describe('fetchRules', () => {
    beforeEach(() => {
      state = {
        ...state,
        approvals: {
          rules: [TEST_RULE],
          rulesPagination: {
            nextPage: 1,
            total: 20,
          },
        },
      };
    });

    it('defaults to page 1 if pagination information is not available', () => {
      jest.spyOn(axios, 'get');
      state.approvals.rulesPagination = {};
      actions.fetchRules({ rootState: state, dispatch: jest.fn() });

      expect(axios.get).toHaveBeenCalledWith(TEST_RULES_PATH, { params: { page: 1 } });
    });

    it('dispatches request/receive', async () => {
      const data = [TEST_RULE_RESPONSE];

      mock.onGet(TEST_RULES_PATH).replyOnce(HTTP_STATUS_OK, data, mockHeaders);

      await testAction(
        actions.fetchRules,
        null,
        state,
        [],
        [
          { type: 'requestRules' },
          {
            type: 'receiveRulesSuccess',
            payload: {
              approvalSettings: mapApprovalSettingsResponse(data),
              pagination: {
                nextPage: mockHeaders['X-Next-Page'],
                total: mockHeaders['X-Total'],
              },
            },
          },
        ],
      );
      expect(mock.history.get.map((x) => x.url)).toEqual([TEST_RULES_PATH]);
    });

    it('dispatches request/receive on error', () => {
      mock.onGet(TEST_RULES_PATH).replyOnce(HTTP_STATUS_INTERNAL_SERVER_ERROR);

      return testAction(
        actions.fetchRules,
        null,
        state,
        [],
        [{ type: 'requestRules' }, { type: 'receiveRulesError' }],
      );
    });
  });

  describe('postRuleSuccess', () => {
    it('closes modal and fetches', () => {
      return testAction(
        actions.postRuleSuccess,
        null,
        {},
        [],
        [{ type: 'updateRules', payload: null }],
      );
    });
  });

  describe('postRule', () => {
    it('dispatches success on success', async () => {
      mock.onPost(TEST_RULES_PATH).replyOnce(HTTP_STATUS_OK);

      await testAction(
        actions.postRule,
        TEST_RULE_REQUEST,
        state,
        [],
        [{ type: 'postRuleSuccess' }],
      );
      expect(mock.history.post).toEqual([
        expect.objectContaining({
          url: TEST_RULES_PATH,
          data: JSON.stringify(mapApprovalRuleRequest(TEST_RULE_REQUEST)),
        }),
      ]);
    });
  });

  describe('putRule', () => {
    it('dispatches success on success', async () => {
      mock.onPut(`${TEST_RULES_PATH}/${TEST_RULE_ID}`).replyOnce(HTTP_STATUS_OK);

      await testAction(
        actions.putRule,
        { id: TEST_RULE_ID, ...TEST_RULE_REQUEST },
        state,
        [],
        [{ type: 'postRuleSuccess' }],
      );
      expect(mock.history.put).toEqual([
        expect.objectContaining({
          url: `${TEST_RULES_PATH}/${TEST_RULE_ID}`,
          data: JSON.stringify(mapApprovalRuleRequest(TEST_RULE_REQUEST)),
        }),
      ]);
    });
  });

  describe('deleteRuleSuccess', () => {
    it('closes modal and fetches', () => {
      return testAction(
        actions.deleteRuleSuccess,
        { newRules: TEST_RULE_RESPONSE, totalRules: 20 },
        {},
        [],
        [
          { type: 'deleteModal/close' },
          { type: 'setRules', payload: { rules: TEST_RULE_RESPONSE, totalRules: 20 } },
        ],
      );
    });
  });

  describe('deleteRuleError', () => {
    it('creates an alert', () => {
      expect(createAlert).not.toHaveBeenCalled();

      actions.deleteRuleError();

      expect(createAlert.mock.calls[0]).toEqual([
        { message: expect.stringMatching('error occurred') },
      ]);
    });
  });

  describe('deleteRule', () => {
    beforeEach(() => {
      state = {
        ...state,
        approvals: {
          rules: [TEST_RULE],
          rulesPagination: {
            nextPage: 1,
            total: 20,
          },
        },
      };
    });

    it('dispatches success on success', async () => {
      mock.onDelete(`${TEST_RULES_PATH}/${TEST_RULE_ID}`).replyOnce(HTTP_STATUS_OK);

      await testAction(
        actions.deleteRule,
        TEST_RULE_ID,
        state,
        [],
        [
          {
            type: 'deleteRuleSuccess',
            payload: { newRules: [TEST_RULE], totalRules: 19 },
          },
        ],
      );
      expect(mock.history.delete).toEqual([
        expect.objectContaining({
          url: `${TEST_RULES_PATH}/${TEST_RULE_ID}`,
        }),
      ]);
    });

    it('dispatches error on error', () => {
      mock
        .onDelete(`${TEST_RULES_PATH}/${TEST_RULE_ID}`)
        .replyOnce(HTTP_STATUS_INTERNAL_SERVER_ERROR);

      return testAction(actions.deleteRule, TEST_RULE_ID, state, [], [{ type: 'deleteRuleError' }]);
    });
  });
});
