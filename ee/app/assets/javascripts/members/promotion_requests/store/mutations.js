import * as types from './mutation_types';

export default {
  [types.UPDATE_TOTAL_ITEMS](state, totalItems) {
    state.pagination.totalItems = totalItems;
  },
};
