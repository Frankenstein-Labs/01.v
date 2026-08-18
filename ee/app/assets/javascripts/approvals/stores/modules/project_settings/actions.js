import {
  mapApprovalRuleRequest,
  mapApprovalRuleResponse,
  mapApprovalSettingsResponse,
  mapApprovalFallbackRuleRequest,
  excludeDuplicatesInResponse,
} from 'ee/approvals/mappers';
import { createAlert } from '~/alert';
import axios from '~/lib/utils/axios_utils';
import { normalizeHeaders, parseIntPagination } from '~/lib/utils/common_utils';
import { __ } from '~/locale';
import * as types from '../base/mutation_types';

export const requestRules = ({ commit }) => {
  commit(types.SET_LOADING, true);
};

export const setRulesFilter = ({ commit }, rules) => {
  commit(types.SET_RULES_FILTER, rules);
};

export const receiveRulesSuccess = ({ commit }, { approvalSettings, pagination }) => {
  commit(types.SET_APPROVAL_SETTINGS, { ...approvalSettings, isPagination: true });
  commit(types.SET_RULES_PAGINATION, pagination);
  commit(types.SET_LOADING, false);
};

export const openCreateDrawer = ({ commit }, rule) => {
  commit(types.SET_DRAWER_OPEN, true);
  commit(types.SET_EDIT_RULE, rule);
};

export const closeCreateDrawer = ({ commit }) => {
  commit(types.SET_DRAWER_OPEN, false);
  commit(types.SET_EDIT_RULE, null);
};

export const receiveRulesError = () => {
  createAlert({
    message: __('An error occurred fetching the approval rules.'),
  });
};

export const fetchRules = ({ rootState, dispatch }) => {
  dispatch('requestRules');

  const { rulesPath } = rootState.settings;
  const { rulesPagination: p, rules: rulesInState, rulesFilter: filter } = rootState.approvals;
  const params = { page: p.nextPage || 1 };

  return axios
    .get(rulesPath, { params })
    .then(({ data, headers }) => {
      const { nextPage, total } = parseIntPagination(normalizeHeaders(headers));

      const newRules = excludeDuplicatesInResponse(data, rulesInState);
      const rules = filter ? newRules.filter(({ name }) => filter.includes(name)) : newRules;

      dispatch('receiveRulesSuccess', {
        approvalSettings: mapApprovalSettingsResponse(rules, filter),
        pagination: { nextPage, total },
      });
    })
    .catch(() => dispatch('receiveRulesError'));
};

export const setRules = ({ commit }, { rules, totalRules }) => {
  commit(types.SET_RULES, rules);
  commit(types.SET_RULES_PAGINATION, { total: totalRules });
};

export const updateRules = ({ rootState, dispatch }, updatedRule) => {
  const { rules, rulesPagination } = rootState.approvals;
  const normalizedRule = mapApprovalRuleResponse(updatedRule);
  const hasRule = rules.some(({ id }) => id === updatedRule.id);

  const isAnyApproverPlaceholder =
    updatedRule.rule_type === 'any_approver' &&
    rules.some((r) => r.id === null && r.ruleType === 'any_approver');

  const isUpdatingExistingRule = hasRule || isAnyApproverPlaceholder;

  let newRules;
  if (hasRule) {
    newRules = rules.map((r) => (r.id === updatedRule.id ? normalizedRule : r));
  } else if (isAnyApproverPlaceholder) {
    newRules = rules.map((r) =>
      r.id === null && r.ruleType === 'any_approver' ? normalizedRule : r,
    );
  } else {
    newRules = [...rules, normalizedRule];
  }

  const totalRules = isUpdatingExistingRule ? rulesPagination.total : rulesPagination.total + 1;

  dispatch('setRules', { rules: newRules, totalRules });
};

export const postRuleSuccess = ({ dispatch }, updatedRule) => {
  dispatch('updateRules', updatedRule);
};

export const postRule = ({ rootState, dispatch }, rule) => {
  const { rulesPath } = rootState.settings;

  return axios
    .post(rulesPath, mapApprovalRuleRequest(rule))
    .then(({ data }) => dispatch('postRuleSuccess', data));
};

export const putRule = ({ rootState, dispatch }, { id, ...newRule }) => {
  const { rulesPath } = rootState.settings;

  return axios
    .put(`${rulesPath}/${id}`, mapApprovalRuleRequest(newRule))
    .then(({ data }) => dispatch('postRuleSuccess', data));
};

export const deleteRuleSuccess = ({ dispatch }, { newRules, totalRules }) => {
  dispatch('deleteModal/close');
  dispatch('setRules', { rules: newRules, totalRules });
};

export const deleteRuleError = () => {
  createAlert({
    message: __('An error occurred while deleting the approvers group'),
  });
};

export const deleteRule = ({ rootState, dispatch }, id) => {
  const { rulesPath } = rootState.settings;

  return axios
    .delete(`${rulesPath}/${id}`)
    .then(() => {
      const { rules, rulesPagination } = rootState.approvals;
      const newRules = rules.filter((rule) => rule.id !== id);
      const totalRules = rulesPagination.total - 1;

      dispatch('deleteRuleSuccess', { newRules, totalRules });
    })
    .catch(() => dispatch('deleteRuleError'));
};

export const putFallbackRuleSuccess = ({ dispatch }) => {
  dispatch('fetchRules');
};

export const putFallbackRule = ({ rootState, dispatch }, fallback) => {
  const { projectPath } = rootState.settings;

  return axios
    .put(projectPath, mapApprovalFallbackRuleRequest(fallback))
    .then(() => dispatch('putFallbackRuleSuccess'));
};

export const requestEditRule = ({ dispatch }, rule) => {
  dispatch('openCreateDrawer', rule);
};

export const requestDeleteRule = ({ dispatch }, rule) => {
  dispatch('deleteModal/open', rule);
};

export const addEmptyRule = ({ commit }) => {
  commit(types.ADD_EMPTY_RULE);
};
