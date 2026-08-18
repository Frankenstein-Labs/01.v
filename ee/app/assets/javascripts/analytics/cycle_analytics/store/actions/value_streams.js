import { deleteValueStream as apiDeleteValueStream, getValueStreams } from 'ee/api/analytics_api';
import * as types from '../mutation_types';

export const deleteValueStream = ({ commit, dispatch, getters }, valueStreamId) => {
  const { namespaceRestApiRequestPath } = getters;
  commit(types.REQUEST_DELETE_VALUE_STREAM);

  return apiDeleteValueStream(namespaceRestApiRequestPath, valueStreamId)
    .then(() => commit(types.RECEIVE_DELETE_VALUE_STREAM_SUCCESS))
    .then(() => dispatch('fetchCycleAnalyticsData'))
    .catch(({ response } = {}) => {
      const { data: { message } = null } = response;
      commit(types.RECEIVE_DELETE_VALUE_STREAM_ERROR, message);
    });
};

export const fetchValueStreamData = ({ dispatch }) =>
  Promise.resolve()
    .then(() => dispatch('fetchGroupStages'))
    .then(() => dispatch('fetchStageCountValues'))
    .then(() => dispatch('fetchStageMedianValues'));

export const setSelectedValueStream = ({ commit, dispatch }, valueStream) => {
  commit(types.SET_SELECTED_VALUE_STREAM, valueStream);
  dispatch('setDefaultSelectedStage');
  return dispatch('fetchValueStreamData');
};

export const receiveValueStreamsSuccess = (
  { state: { selectedValueStream = null }, commit, dispatch },
  data = [],
) => {
  commit(types.RECEIVE_VALUE_STREAMS_SUCCESS, data);

  if (!selectedValueStream && !data.length) {
    return dispatch('fetchGroupStages');
  }

  if (!selectedValueStream && data.length) {
    const [firstStream] = data;
    return Promise.resolve()
      .then(() => dispatch('setSelectedValueStream', firstStream))
      .then(() => dispatch('fetchStageCountValues'));
  }

  return Promise.resolve().then(() => dispatch('fetchValueStreamData'));
};

export const fetchValueStreams = ({ commit, dispatch, getters }) => {
  const { namespaceRestApiRequestPath } = getters;

  commit(types.REQUEST_VALUE_STREAMS);

  return getValueStreams(namespaceRestApiRequestPath)
    .then(({ data }) => dispatch('receiveValueStreamsSuccess', data))
    .catch((error) => {
      const {
        response: { status },
      } = error;
      commit(types.RECEIVE_VALUE_STREAMS_ERROR, status);
      throw error;
    });
};
