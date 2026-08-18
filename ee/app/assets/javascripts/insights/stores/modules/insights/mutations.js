import { pick } from 'lodash-es';

import { INSIGHTS_DATA_SOURCE_DORA } from 'ee/insights/constants';
import { transformChartDataForGlCharts } from './helpers';
import * as types from './mutation_types';

export default {
  [types.REQUEST_CONFIG](state) {
    state.configData = null;
    state.configLoading = true;
  },
  [types.RECEIVE_CONFIG_SUCCESS](state, data) {
    state.configData = pick(
      data,
      Object.keys(data).filter((key) => data[key].title && data[key].charts),
    );
    state.configLoading = false;
  },
  [types.RECEIVE_CONFIG_ERROR](state) {
    state.configData = null;
    state.configLoading = false;
  },

  [types.RECEIVE_CHART_SUCCESS](state, { chart, data }) {
    const { type, description, query } = chart;

    const { data_source: dataSource } = query;

    const {
      issuable_type: issuableType,
      metric,
      filter_labels: filterLabels = [],
      collection_labels: collectionLabels = [],
      group_by: groupBy,
    } = query.params || {};

    state.chartData[chart.title] = {
      type,
      description,
      data: transformChartDataForGlCharts(chart, data),
      dataSourceType: dataSource === INSIGHTS_DATA_SOURCE_DORA ? metric : issuableType,
      loaded: true,
      filterLabels,
      collectionLabels,
      groupBy,
    };
  },
  [types.RECEIVE_CHART_ERROR](state, { chart, error }) {
    const { type } = chart;

    state.chartData[chart.title] = {
      type,
      data: {},
      loaded: false,
      error,
    };
  },

  [types.SET_ACTIVE_TAB](state, tab) {
    state.activeTab = tab;
  },
  [types.SET_ACTIVE_PAGE](state, pageData) {
    state.activePage = pageData;
  },
  [types.INIT_CHART_DATA](state, keys) {
    state.chartData = keys.reduce((acc, key) => {
      acc[key] = {};
      return acc;
    }, {});
  },
};
