import { SORT_ORDERS, SORT_ASCENDING, SORT_DESCENDING } from './constants';
import * as types from './mutation_types';

export default {
  [types.SET_DEPENDENCIES_ENDPOINT](state, payload) {
    state.endpoint = payload;
  },
  [types.SET_EXPORT_DEPENDENCIES_ENDPOINT](state, exportEndpoint) {
    state.exportEndpoint = exportEndpoint;
  },
  [types.SET_NAMESPACE_TYPE](state, namespaceType) {
    state.namespaceType = namespaceType;
  },
  [types.SET_FETCHING_IN_PROGRESS](state, fetchingInProgress) {
    state.fetchingInProgress = fetchingInProgress;
  },
  [types.SET_PAGE_INFO](state, pageInfo) {
    state.pageInfo = pageInfo;
  },
  [types.REQUEST_DEPENDENCIES](state) {
    state.isLoading = true;
    state.errorLoading = false;
  },
  [types.RECEIVE_DEPENDENCIES_SUCCESS](state, { dependencies, pageInfo }) {
    state.dependencies = dependencies;
    state.pageInfo = pageInfo;
    state.isLoading = false;
    state.errorLoading = false;
    state.initialized = true;
  },
  [types.RECEIVE_DEPENDENCIES_ERROR](state) {
    state.isLoading = false;
    state.errorLoading = true;
    state.dependencies = [];
    state.pageInfo = {};
    state.initialized = true;
  },
  [types.SET_SEARCH_FILTER_PARAMETERS](state, parameters) {
    state.searchFilterParameters = parameters;
  },
  [types.SET_SORT_FIELD](state, payload) {
    state.sortField = payload;
    state.sortOrder = SORT_ORDERS[payload];
  },
  [types.TOGGLE_SORT_ORDER](state) {
    state.sortOrder = state.sortOrder === SORT_ASCENDING ? SORT_DESCENDING : SORT_ASCENDING;
  },
  [types.SET_LICENSES](state, licenses) {
    state.licenses = licenses;
  },
  [types.SET_FETCHING_LICENSES_IN_PROGRESS](state, fetchLicensesInProgress) {
    state.fetchingLicensesInProgress = fetchLicensesInProgress;
  },
  [types.SET_VULNERABILITIES](state, payload) {
    if (payload.length) {
      const id = parseInt(payload[0].occurrence_id, 10);
      state.vulnerabilityInfo[id] = payload;
    }
  },
  [types.TOGGLE_VULNERABILITY_ITEM_LOADING](state, item) {
    if (state.vulnerabilityItemsLoading.includes(item)) {
      state.vulnerabilityItemsLoading = state.vulnerabilityItemsLoading.filter((i) => i !== item);
    } else {
      state.vulnerabilityItemsLoading.push(item);
    }
  },
  [types.SET_FULL_PATH](state, fullPath) {
    state.fullPath = fullPath;
  },
};
