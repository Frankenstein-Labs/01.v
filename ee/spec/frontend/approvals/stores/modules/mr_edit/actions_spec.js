import * as actions from 'ee/approvals/stores/modules/mr_edit/actions';
import * as types from 'ee/approvals/stores/modules/mr_edit/mutation_types';
import testAction from 'helpers/vuex_action_helper';

describe('Approval MR edit module actions', () => {
  describe('setTargetBranch', () => {
    it('commits SET_TARGET_BRANCH', async () => {
      await testAction(
        actions.setTargetBranch,
        'main',
        {},
        [{ type: types.SET_TARGET_BRANCH, payload: 'main' }],
        [],
      );
    });
  });

  describe('undoRulesChange', () => {
    it('commits UNDO_RULES', async () => {
      await testAction(actions.undoRulesChange, null, {}, [{ type: types.UNDO_RULES }], []);
    });
  });

  describe('drawer', () => {
    it('openCreateDrawer', () => {
      return testAction(
        actions.openCreateDrawer,
        '',
        {},
        [
          { type: types.SET_DRAWER_OPEN, payload: true },
          { type: types.SET_EDIT_RULE, payload: '' },
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
});
