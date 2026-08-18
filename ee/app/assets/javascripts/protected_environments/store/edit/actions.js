import { getUser, getProjectMembers, getGroupMembers } from '~/rest_api';
import Api from 'ee/api';
import { normalizeHeaders, parseIntPagination } from '~/lib/utils/common_utils';
import {
  INHERITED_GROUPS,
  NON_INHERITED_GROUPS,
  RULE_KEYS,
  GROUP_INHERITANCE_KEY,
} from '../../constants';
import * as types from './mutation_types';

const fetchUsersForRuleForProject = (
  entityId,
  entityType,
  {
    user_id: userId,
    group_id: groupId,
    group_inheritance_type: groupInheritanceType,
    access_level: accessLevel,
  },
) => {
  if (userId != null) {
    return getUser(userId).then(({ data }) => [data]);
  }
  if (groupId != null) {
    return getGroupMembers(groupId, groupInheritanceType === INHERITED_GROUPS).then(
      ({ data }) => data,
    );
  }

  const isInherited = groupInheritanceType === INHERITED_GROUPS;
  // Currently only 'projects' and 'groups' entity types exist
  let fetchMembers;

  if (entityType === 'projects') {
    fetchMembers = getProjectMembers(entityId, isInherited);
  } else if (entityType === 'groups') {
    fetchMembers = getGroupMembers(entityId, isInherited);
  } else {
    throw new Error(`Unexpected entityType: ${entityType}`);
  }

  return fetchMembers.then(({ data }) =>
    data.filter(({ access_level: memberAccessLevel }) => memberAccessLevel >= accessLevel),
  );
};

export const fetchProtectedEnvironments = ({ state, commit, dispatch }) => {
  commit(types.REQUEST_PROTECTED_ENVIRONMENTS);

  const params = {
    page: state.pageInfo?.page ?? null,
  };

  return Api.protectedEnvironments(state.entityId, state.entityType, params)
    .then(({ data, headers }) => {
      commit(types.RECEIVE_PROTECTED_ENVIRONMENTS_SUCCESS, data);
      dispatch('fetchAllMembers');

      const normalizedHeaders = normalizeHeaders(headers);
      const pageInfo = parseIntPagination(normalizedHeaders);
      commit(types.SET_PAGINATION, pageInfo);
    })
    .catch((error) => {
      commit(types.RECEIVE_PROTECTED_ENVIRONMENTS_ERROR, error);
    });
};

export const setPage = ({ commit, dispatch }, page) => {
  commit(types.SET_PAGE, page);

  dispatch('fetchProtectedEnvironments');
};

export const fetchAllMembers = async ({ state, dispatch, commit }) => {
  commit(types.REQUEST_MEMBERS);

  try {
    await Promise.all(
      state.protectedEnvironments.flatMap((env) => dispatch('fetchAllMembersForEnvironment', env)),
    );
  } finally {
    commit(types.RECEIVE_MEMBERS_FINISH);
  }
};

export const fetchAllMembersForEnvironment = ({ dispatch }, environment) => {
  RULE_KEYS.flatMap((type) =>
    environment[type].map((rule) => dispatch('fetchMembers', { type, rule })),
  );
};

export const fetchMembers = ({ state, commit }, { type, rule }) => {
  return fetchUsersForRuleForProject(state.entityId, state.entityType, rule)
    .then((users) => {
      commit(types.RECEIVE_MEMBER_SUCCESS, { type, rule, users });
    })
    .catch((error) => {
      commit(types.RECEIVE_MEMBERS_ERROR, error);
    });
};

export const deleteRule = ({ dispatch }, { environment, rule, ruleKey }) => {
  const deletedRuleEntries = [
    ['_destroy', true],
    ...Object.entries(rule).filter(([, value]) => value),
  ];
  const updatedEnvironment = {
    name: environment.name,
    [ruleKey]: [Object.fromEntries(deletedRuleEntries)],
  };

  dispatch('updateEnvironment', updatedEnvironment);
};

export const setRule = ({ commit }, { environment, newRules }) =>
  commit(types.SET_RULE, { environment, rules: newRules });

export const saveRule = ({ dispatch, state }, { environment, ruleKey }) => {
  const newDeployAccessLevels = state.newDeployAccessLevelsForEnvironment[environment.name].filter(
    ({ user_id: newUserId, group_id: newGroupId, access_level: newAccessLevel }) =>
      !environment[ruleKey].some(
        ({ user_id: userId, group_id: groupId, access_level: accessLevel }) =>
          (userId !== null && newUserId === userId) ||
          (groupId !== null && newGroupId === groupId) ||
          (accessLevel !== null && newAccessLevel === accessLevel),
      ),
  );
  return dispatch('updateEnvironment', {
    name: environment.name,
    [ruleKey]: newDeployAccessLevels,
  });
};

export const updateRule = ({ dispatch, state, commit }, { environment, ruleKey, rule }) => {
  const updatedRuleEntries = Object.entries(state.editingRules[rule.id]).filter(
    ([key, value]) => value || key === GROUP_INHERITANCE_KEY,
  );
  const updatedEnvironment = {
    name: environment.name,
    [ruleKey]: [Object.fromEntries(updatedRuleEntries)],
  };
  return dispatch('updateEnvironment', updatedEnvironment).then(() => {
    commit(types.RECEIVE_RULE_UPDATED, rule);
  });
};

export const updateEnvironment = ({ state, commit, dispatch }, environment) => {
  commit(types.REQUEST_UPDATE_PROTECTED_ENVIRONMENT);

  return Api.updateProtectedEnvironment(state.entityId, state.entityType, environment)
    .then(({ data }) => {
      commit(types.RECEIVE_UPDATE_PROTECTED_ENVIRONMENT_SUCCESS, data);
      dispatch('fetchAllMembersForEnvironment', data);
    })
    .catch((error) => {
      commit(types.RECEIVE_UPDATE_PROTECTED_ENVIRONMENT_ERROR, error);
    });
};

export const updateApproverInheritance = ({ commit }, { rule, value }) => {
  commit(types.EDIT_RULE, {
    ...rule,
    group_inheritance_type: value ? INHERITED_GROUPS : NON_INHERITED_GROUPS,
  });
};

export const updateRequiredApprovals = ({ commit }, { rule, value }) => {
  commit(types.EDIT_RULE, {
    ...rule,
    required_approvals: value,
  });
};

export const editRule = ({ commit }, rule) => commit(types.EDIT_RULE, rule);

export const unprotectEnvironment = ({ state, commit, dispatch }, environment) => {
  commit(types.REQUEST_UPDATE_PROTECTED_ENVIRONMENT);

  return Api.deleteProtectedEnvironment(state.entityId, state.entityType, environment)
    .then(() => {
      commit(types.DELETE_PROTECTED_ENVIRONMENT_SUCCESS, environment);

      if (!state.protectedEnvironments.length && state.pageInfo.page > 1) {
        dispatch('setPage', state.pageInfo.page - 1);
      }
    })
    .catch((error) => {
      commit(types.RECEIVE_UPDATE_PROTECTED_ENVIRONMENT_ERROR, error);
    });
};
