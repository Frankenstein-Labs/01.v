import * as types from './mutation_types';

export const mutations = {
  [types.REQUEST_PROTECTED_ENVIRONMENTS](state) {
    state.loading = true;
  },
  [types.RECEIVE_PROTECTED_ENVIRONMENTS_SUCCESS](state, environments) {
    state.loading = false;
    state.protectedEnvironments = environments;
    state.newDeployAccessLevelsForEnvironment = Object.fromEntries(
      environments.map(({ name }) => [name, []]),
    );
  },
  [types.RECEIVE_PROTECTED_ENVIRONMENTS_ERROR](state) {
    state.loading = false;
  },
  [types.SET_PAGINATION](state, pageInfo) {
    state.pageInfo = pageInfo;
  },
  [types.SET_PAGE](state, page) {
    state.pageInfo = { ...state.pageInfo, page };
  },
  [types.REQUEST_MEMBERS](state) {
    state.loading = true;
  },
  [types.RECEIVE_MEMBERS_FINISH](state) {
    state.loading = false;
  },
  [types.RECEIVE_MEMBERS_ERROR](state) {
    state.loading = false;
  },
  [types.RECEIVE_MEMBER_SUCCESS](state, { type, rule, users }) {
    state.usersForRules = {
      ...state.usersForRules,
      [`${type}-${rule.id}`]: users,
    };
  },
  [types.REQUEST_UPDATE_PROTECTED_ENVIRONMENT](state) {
    state.loading = true;
  },
  [types.RECEIVE_UPDATE_PROTECTED_ENVIRONMENT_SUCCESS](state, environment) {
    const index = state.protectedEnvironments.findIndex((env) => env.name === environment.name);
    state.protectedEnvironments[index] = environment;
    state.newDeployAccessLevelsForEnvironment = {
      ...state.newDeployAccessLevelsForEnvironment,
      [environment.name]: [],
    };

    state.loading = false;
  },
  [types.RECEIVE_UPDATE_PROTECTED_ENVIRONMENT_ERROR](state) {
    state.loading = false;
  },
  [types.SET_RULE](state, { environment, rules }) {
    state.newDeployAccessLevelsForEnvironment[environment.name] = rules;
  },
  [types.EDIT_RULE](state, rule) {
    state.editingRules = {
      ...state.editingRules,
      [rule.id]: { ...rule },
    };
  },
  [types.RECEIVE_RULE_UPDATED](state, rule) {
    state.editingRules = {
      ...state.editingRules,
      [rule.id]: null,
    };
  },
  [types.DELETE_PROTECTED_ENVIRONMENT_SUCCESS](state, { name }) {
    state.protectedEnvironments = state.protectedEnvironments.filter((env) => env.name !== name);
    state.newDeployAccessLevelsForEnvironment = {
      ...state.newDeployAccessLevelsForEnvironment,
      [name]: [],
    };

    state.loading = false;
  },
};
