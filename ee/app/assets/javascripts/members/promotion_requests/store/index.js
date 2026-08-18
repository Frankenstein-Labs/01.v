import createState from './state';
import * as actions from './actions';
import mutations from './mutations';

export default (initialState) => ({
  namespaced: true,
  actions,
  state: createState(initialState),
  mutations,
});
