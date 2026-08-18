import Vue from 'vue';
import VueApollo from 'vue-apollo';
// eslint-disable-next-line no-restricted-imports
import Vuex from 'vuex';
import { shallowMount } from '@vue/test-utils';
import { GlAlert } from '@gitlab/ui';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import ChartSkeletonLoader from '~/vue_shared/components/resizable_chart/skeleton_loader.vue';
import waitForPromises from 'helpers/wait_for_promises';
import createMockApollo from 'helpers/mock_apollo_helper';
import { createdAfter, createdBefore } from 'jest/analytics/cycle_analytics/mock_data';
import DurationChartLoader from 'ee/analytics/cycle_analytics/components/duration_charts/duration_chart_loader.vue';
import StageChart from 'ee/analytics/cycle_analytics/components/duration_charts/stage_chart.vue';
import OverviewChart from 'ee/analytics/cycle_analytics/components/duration_charts/overview_chart.vue';
import getValueStreamStageAverageDurationsQuery from 'ee/analytics/cycle_analytics/graphql/queries/get_value_stream_stage_average_durations.query.graphql';
import {
  allowedStages as stages,
  valueStreams,
  averageDurationsStageQueryResponses,
} from '../../mock_data';

Vue.use(Vuex);
Vue.use(VueApollo);

jest.mock('~/sentry/sentry_browser_wrapper');

describe('DurationChartLoader', () => {
  let wrapper;
  let store;
  let averageDurationsQueryHandler;

  const [valueStream] = valueStreams;
  const [selectedStage] = stages;
  const namespacePath = 'fake/group/path';
  const namespace = {
    name: 'GitLab Org',
    path: namespacePath,
  };

  const cycleAnalyticsRequestParams = {
    project_ids: null,
    created_after: '2019-12-11',
    created_before: '2020-01-10',
    author_username: null,
    milestone_title: null,
    assignee_username: null,
    'not[label_name]': null,
  };

  const createStore = ({ isOverviewStageSelected, isProjectNamespace }) =>
    new Vuex.Store({
      state: {
        selectedStage,
        createdAfter,
        createdBefore,
        namespace: {
          ...namespace,
          type: isProjectNamespace ? 'Project' : 'Group',
        },
      },
      getters: {
        isOverviewStageSelected: () => isOverviewStageSelected,
        activeStages: () => stages,
        cycleAnalyticsRequestParams: () => cycleAnalyticsRequestParams,
        currentValueStreamId: () => valueStream.id,
        isProjectNamespace: () => isProjectNamespace,
      },
      mutations: {
        setSelectedStage: (rootState, value) => {
          // eslint-disable-next-line no-param-reassign
          rootState.selectedStage = value;
        },
      },
    });

  const createWrapper = ({
    isOverviewStageSelected = true,
    isProjectNamespace = false,
    averageDurationsResponseHandler = null,
  } = {}) => {
    averageDurationsQueryHandler =
      averageDurationsResponseHandler ||
      jest
        .fn()
        .mockResolvedValueOnce(averageDurationsStageQueryResponses[0])
        .mockResolvedValueOnce(averageDurationsStageQueryResponses[1])
        .mockResolvedValueOnce(averageDurationsStageQueryResponses[2]);

    const apolloProvider = createMockApollo([
      [getValueStreamStageAverageDurationsQuery, averageDurationsQueryHandler],
    ]);

    store = createStore({ isOverviewStageSelected, isProjectNamespace });

    wrapper = shallowMount(DurationChartLoader, {
      store,
      apolloProvider,
    });
    return waitForPromises();
  };

  const findLoader = () => wrapper.findComponent(ChartSkeletonLoader);
  const findAlert = () => wrapper.findComponent(GlAlert);
  const findOverviewChart = () => wrapper.findComponent(OverviewChart);
  const findStageChart = () => wrapper.findComponent(StageChart);

  describe('fetches chart data', () => {
    describe('default', () => {
      beforeEach(() => {
        return createWrapper();
      });

      it('fetches overview chart data', () => {
        expect(averageDurationsQueryHandler).toHaveBeenCalledTimes(stages.length);
      });

      it('fetches chart data when `selectedStage` changes', async () => {
        const [, newStage] = stages;
        store.commit('setSelectedStage', newStage);

        await waitForPromises();

        expect(averageDurationsQueryHandler).toHaveBeenCalledTimes(stages.length);
      });
    });
  });

  describe('overview chart', () => {
    describe('when loading', () => {
      beforeEach(() => {
        createWrapper();
      });

      it('shows the loading state', () => {
        expect(findLoader().exists()).toBe(true);
      });
    });

    describe('when error is thrown', () => {
      beforeEach(() => {
        return createWrapper({
          averageDurationsResponseHandler: jest.fn().mockRejectedValue(new Error('oopsies')),
        });
      });

      it('shows the error message', () => {
        expect(findAlert().text()).toBe('oopsies');
      });

      it('logs the error to sentry', () => {
        expect(Sentry.captureException).toHaveBeenCalled();
      });
    });

    describe('with data', () => {
      beforeEach(() => {
        return createWrapper();
      });

      it('shows the chart with the plottable data', () => {
        expect(findOverviewChart().props().plottableData).toMatchSnapshot();
      });

      it('does not show the stage chart', () => {
        expect(findStageChart().exists()).toBe(false);
      });
    });
  });

  describe('stage chart', () => {
    describe('when loading', () => {
      beforeEach(() => {
        createWrapper({
          isOverviewStageSelected: false,
        });
      });

      it('shows the loading state', () => {
        expect(findLoader().exists()).toBe(true);
      });
    });

    describe('when error is thrown', () => {
      beforeEach(() => {
        return createWrapper({
          isOverviewStageSelected: false,
          averageDurationsResponseHandler: jest.fn().mockRejectedValue(new Error('oopsies')),
        });
      });

      it('shows the error message', () => {
        expect(findAlert().text()).toBe('oopsies');
      });

      it('logs the error to sentry', () => {
        expect(Sentry.captureException).toHaveBeenCalled();
      });
    });

    describe('with data', () => {
      beforeEach(() => {
        return createWrapper({
          isOverviewStageSelected: false,
        });
      });

      it('shows the chart with the plottable data', () => {
        expect(findStageChart().props().stageTitle).toBe(selectedStage.title);
        expect(findStageChart().props().plottableData).toMatchSnapshot();
      });

      it('does not show the overview chart', () => {
        expect(findOverviewChart().exists()).toBe(false);
      });
    });
  });
});
