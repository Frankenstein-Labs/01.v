import * as types from 'ee/approvals/stores/modules/base/mutation_types';
import mutations from 'ee/approvals/stores/modules/base/mutations';
import createState from 'ee/approvals/stores/state';

describe('EE approvals base module mutations', () => {
  let state;

  beforeEach(() => {
    state = createState();
  });

  describe(types.SET_LOADING, () => {
    it('sets isLoading', () => {
      state.isLoading = false;

      mutations[types.SET_LOADING](state, true);

      expect(state.isLoading).toBe(true);
    });
  });

  describe(types.SET_RULES_FILTER, () => {
    it('sets rulesFilter', () => {
      const filter = ['test'];
      state.rulesFilter = [];

      mutations[types.SET_RULES_FILTER](state, filter);

      expect(state.rulesFilter).toStrictEqual(filter);
    });
  });

  describe(types.SET_APPROVAL_SETTINGS, () => {
    it('sets rules', () => {
      const settings = {
        rules: [{ id: 3 }, { id: 4 }],
        fallbackApprovalsRequired: 7,
        minFallbackApprovalsRequired: 1,
      };

      state.rules = [{ id: 1 }, { id: 2 }];

      mutations[types.SET_APPROVAL_SETTINGS](state, settings);

      expect(state).toEqual(expect.objectContaining(settings));
    });

    it('merges newly fetched rules with existing ones in the case of pagination', () => {
      const settings = {
        rules: [{ id: 3 }, { id: 4 }],
        fallbackApprovalsRequired: 7,
        minFallbackApprovalsRequired: 1,
      };
      const initialStateRules = [{ id: 1 }, { id: 2 }];

      state.hasLoaded = false;
      state.rules = initialStateRules;

      mutations[types.SET_APPROVAL_SETTINGS](state, { ...settings, isPagination: true });

      expect(state).toEqual(
        expect.objectContaining({ ...settings, rules: [...initialStateRules, ...settings.rules] }),
      );
    });
  });

  describe(types.SET_RESET_TO_DEFAULT, () => {
    it('resets rules', () => {
      state.rules = ['test'];

      mutations[types.SET_RESET_TO_DEFAULT](state, true);

      expect(state.resetToDefault).toBe(true);
      expect(state.oldRules).toEqual(['test']);
    });
  });

  describe(types.UNDO_RULES, () => {
    it('undos rules', () => {
      const oldRules = ['old'];
      state.rules = ['new'];
      state.oldRules = oldRules;

      mutations[types.UNDO_RULES](state, true);

      expect(state.resetToDefault).toBe(false);
      expect(state.rules).toEqual(oldRules);
    });
  });

  describe(types.SET_DRAWER_OPEN, () => {
    it('sets drawerOpen', () => {
      const drawerOpen = true;
      mutations[types.SET_DRAWER_OPEN](state, drawerOpen);

      expect(state.drawerOpen).toEqual(drawerOpen);
    });
  });

  describe(types.SET_EDIT_RULE, () => {
    it('sets editRule', () => {
      const editRule = { id: 1 };
      mutations[types.SET_EDIT_RULE](state, editRule);

      expect(state.editRule).toEqual(editRule);
    });
  });

  describe(types.SET_RULES, () => {
    it('replaces data in the `rules` property', () => {
      state.rules = [{ id: 1 }, { id: 2 }];

      const newRules = [{ id: 3 }, { id: 4 }];
      mutations[types.SET_RULES](state, newRules);

      expect(state.rules).toEqual(newRules);
    });
  });

  describe(types.SET_RULES_PAGINATION, () => {
    it('sets pagination data', () => {
      const pagination = { total: 25, nextPage: 2 };
      mutations[types.SET_RULES_PAGINATION](state, pagination);

      expect(state.rulesPagination).toEqual(pagination);
    });
  });
});
