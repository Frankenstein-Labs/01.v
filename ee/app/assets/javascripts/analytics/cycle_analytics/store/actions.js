import { createAlert } from '~/alert';
import { constructPathWithNamespace } from '~/analytics/cycle_analytics/utils';
import { LABELS_ENDPOINT, MILESTONES_ENDPOINT } from '~/analytics/cycle_analytics/constants';
import { HTTP_STATUS_FORBIDDEN, HTTP_STATUS_INTERNAL_SERVER_ERROR } from '~/lib/utils/http_status';
import { __ } from '~/locale';
import * as types from './mutation_types';

export * from './actions/filters';
export * from './actions/stages';
export * from './actions/value_streams';

export const setPaths = ({
  dispatch,
  state: { namespace, groupPath },
  getters: { isProjectNamespace },
}) => {
  const projectPaths = isProjectNamespace
    ? {
        projectEndpoint: namespace.restApiRequestPath,
      }
    : {};

  return dispatch('filters/setEndpoints', {
    labelsEndpoint: constructPathWithNamespace(namespace, LABELS_ENDPOINT),
    milestonesEndpoint: constructPathWithNamespace(namespace, MILESTONES_ENDPOINT),
    groupEndpoint: groupPath,
    ...projectPaths,
  });
};

export const requestCycleAnalyticsData = ({ commit }) => commit(types.REQUEST_VALUE_STREAM_DATA);

export const receiveCycleAnalyticsDataSuccess = ({ commit }) => {
  commit(types.RECEIVE_VALUE_STREAM_DATA_SUCCESS);
};

export const receiveCycleAnalyticsDataError = ({ commit }, { response = {} }) => {
  const { status = HTTP_STATUS_INTERNAL_SERVER_ERROR } = response;

  commit(types.RECEIVE_VALUE_STREAM_DATA_ERROR, status);
  if (status !== HTTP_STATUS_FORBIDDEN) {
    createAlert({
      message: __('There was an error while fetching value stream analytics data.'),
    });
  }
};

export const fetchCycleAnalyticsData = ({ dispatch }) => {
  return Promise.resolve()
    .then(() => dispatch('requestCycleAnalyticsData'))
    .then(() => dispatch('fetchValueStreams'))
    .then(() => dispatch('receiveCycleAnalyticsDataSuccess'))
    .catch((error) => dispatch('receiveCycleAnalyticsDataError', error));
};

export const initializeCycleAnalyticsSuccess = ({ commit }) =>
  commit(types.INITIALIZE_VALUE_STREAM_SUCCESS);

export const initializeCycleAnalytics = ({ dispatch, commit }, initialData = {}) => {
  commit(types.INITIALIZE_VSA, initialData);

  const {
    selectedAuthor,
    selectedMilestone,
    selectedAssigneeList,
    selectedLabelList,
    stage: selectedStage,
    namespace,
  } = initialData;

  if (namespace?.restApiRequestPath) {
    let promises = [
      dispatch('setPaths', { namespacePath: namespace.restApiRequestPath }),
      dispatch('filters/initialize', {
        selectedAuthor,
        selectedMilestone,
        selectedAssigneeList,
        selectedLabelList,
      }),
    ];

    if (selectedStage) {
      promises = [dispatch('setSelectedStage', selectedStage), ...promises];
    } else {
      promises = [dispatch('setDefaultSelectedStage'), ...promises];
    }

    return Promise.all(promises)
      .then(() =>
        Promise.all([
          selectedStage?.id ? dispatch('fetchStageData', selectedStage.id) : Promise.resolve(),
          dispatch('fetchCycleAnalyticsData'),
        ]),
      )
      .then(() => dispatch('initializeCycleAnalyticsSuccess'));
  }

  return dispatch('initializeCycleAnalyticsSuccess');
};
