import { RULE_TYPE_ANY_APPROVER } from '../../../constants';
import * as types from './mutation_types';

export default {
  [types.SET_LOADING](state, isLoading) {
    state.isLoading = isLoading;
  },
  [types.SET_RULES_FILTER](state, rules) {
    state.rulesFilter = rules;
  },
  [types.SET_APPROVAL_SETTINGS](state, settings) {
    state.hasLoaded = true;
    state.rules = settings.isPagination ? [...state.rules, ...settings.rules] : settings.rules;
    state.initialRules = [...settings.rules];
    state.fallbackApprovalsRequired = settings.fallbackApprovalsRequired;
    state.minFallbackApprovalsRequired = settings.minFallbackApprovalsRequired;
  },
  [types.SET_RULES](state, rules) {
    state.rules = [...rules];
  },
  [types.ADD_EMPTY_RULE](state) {
    state.rules.unshift({
      id: null,
      name: '',
      approvalsRequired: 0,
      minApprovalsRequired: 0,
      approvers: [],
      containsHiddenGroups: false,
      users: [],
      groups: [],
      ruleType: RULE_TYPE_ANY_APPROVER,
      isNew: true,
    });
  },
  [types.SET_RESET_TO_DEFAULT](state, resetToDefault) {
    state.resetToDefault = resetToDefault;
    state.oldRules = [...state.rules];
  },
  [types.UNDO_RULES](state) {
    state.resetToDefault = false;
    state.rules = [...state.oldRules];
  },
  [types.SET_DRAWER_OPEN](state, isOpen) {
    state.drawerOpen = isOpen;
  },
  [types.SET_EDIT_RULE](state, rule) {
    state.editRule = rule;
  },
  [types.SET_RULES_PAGINATION](state, pagination) {
    state.rulesPagination = { ...state.rulesPagination, ...pagination };
  },
};
