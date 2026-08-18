import { shallowMount } from '@vue/test-utils';
import MockAdapter from 'axios-mock-adapter';
import Vue from 'vue';
// eslint-disable-next-line no-restricted-imports
import Vuex from 'vuex';
import axios from '~/lib/utils/axios_utils';
import { HTTP_STATUS_NOT_FOUND, HTTP_STATUS_OK } from '~/lib/utils/http_status';
import waitForPromises from 'helpers/wait_for_promises';
import TypeOfWorkChartsLoader from 'ee/analytics/cycle_analytics/components/tasks_by_type/type_of_work_charts_loader.vue';
import TypeOfWorkCharts from 'ee/analytics/cycle_analytics/components/tasks_by_type/type_of_work_charts.vue';
import {
  TASKS_BY_TYPE_SUBJECT_MERGE_REQUEST,
  TASKS_BY_TYPE_SUBJECT_ISSUE,
} from 'ee/analytics/cycle_analytics/constants';
import { createAlert } from '~/alert';
import ChartSkeletonLoader from '~/vue_shared/components/resizable_chart/skeleton_loader.vue';
import { rawTasksByTypeData, groupLabels, groupLabelNames, endpoints } from '../../mock_data';

Vue.use(Vuex);
jest.mock('~/alert');

describe('TypeOfWorkChartsLoader', () => {
  let wrapper;
  let mock;

  const cycleAnalyticsRequestParams = {
    project_ids: null,
    created_after: '2019-12-11',
    created_before: '2020-01-10',
    author_username: null,
    milestone_title: null,
    assignee_username: null,
  };

  const createStore = () =>
    new Vuex.Store({
      state: {
        namespace: {
          restApiRequestPath: 'fake/group/path',
        },
        createdAfter: new Date('2019-12-11'),
        createdBefore: new Date('2020-01-10'),
      },
      getters: {
        cycleAnalyticsRequestParams: () => cycleAnalyticsRequestParams,
      },
    });

  const createWrapper = () => {
    wrapper = shallowMount(TypeOfWorkChartsLoader, {
      store: createStore(),
    });

    return waitForPromises();
  };

  const findLoader = () => wrapper.findComponent(ChartSkeletonLoader);
  const findTypeOfWorkCharts = () => wrapper.findComponent(TypeOfWorkCharts);

  beforeEach(() => {
    mock = new MockAdapter(axios);
  });

  afterEach(() => {
    mock.restore();
  });

  describe('when loading', () => {
    beforeEach(() => {
      createWrapper();
    });

    it('renders skeleton loader', () => {
      expect(findLoader().exists()).toBe(true);
    });
  });

  describe('with data', () => {
    beforeEach(() => {
      mock.onGet(endpoints.tasksByTypeTopLabelsData).replyOnce(HTTP_STATUS_OK, groupLabels);
      mock.onGet(endpoints.tasksByTypeData).replyOnce(HTTP_STATUS_OK, rawTasksByTypeData);
      return createWrapper();
    });

    it('fetches top group labels', () => {
      expect(mock.history.get).toHaveLength(2);
      expect(mock.history.get[0]).toEqual(
        expect.objectContaining({
          url: '/fake/group/path/-/analytics/type_of_work/tasks_by_type/top_labels',
          params: {
            ...cycleAnalyticsRequestParams,
            subject: TASKS_BY_TYPE_SUBJECT_ISSUE,
          },
        }),
      );
    });

    it('fetches tasks by type', () => {
      expect(mock.history.get).toHaveLength(2);
      expect(mock.history.get[1]).toEqual(
        expect.objectContaining({
          url: '/fake/group/path/-/analytics/type_of_work/tasks_by_type',
          params: {
            ...cycleAnalyticsRequestParams,
            subject: TASKS_BY_TYPE_SUBJECT_ISSUE,
            label_names: groupLabelNames,
          },
        }),
      );
    });

    it('renders the type of work charts', () => {
      expect(findTypeOfWorkCharts().props()).toEqual(
        expect.objectContaining({
          subject: TASKS_BY_TYPE_SUBJECT_ISSUE,
          selectedLabelNames: groupLabelNames,
        }),
      );
    });

    it('does not render the loading icon', () => {
      expect(findLoader().exists()).toBe(false);
    });

    describe('when `toggle-label` is emitted', () => {
      beforeEach(() => {
        findTypeOfWorkCharts(wrapper).vm.$emit('toggle-label', groupLabels[0]);
      });

      it('refetches the tasks by type', () => {
        expect(mock.history.get).toHaveLength(3);
        expect(mock.history.get[2]).toEqual(
          expect.objectContaining({
            url: '/fake/group/path/-/analytics/type_of_work/tasks_by_type',
            params: {
              ...cycleAnalyticsRequestParams,
              subject: TASKS_BY_TYPE_SUBJECT_ISSUE,
              label_names: groupLabelNames.slice(1),
            },
          }),
        );
      });
    });

    describe('when `set-subject` is emitted', () => {
      beforeEach(() => {
        findTypeOfWorkCharts(wrapper).vm.$emit('set-subject', TASKS_BY_TYPE_SUBJECT_MERGE_REQUEST);
      });

      it('refetches the tasks by type', () => {
        expect(mock.history.get).toHaveLength(3);
        expect(mock.history.get[2]).toEqual(
          expect.objectContaining({
            url: '/fake/group/path/-/analytics/type_of_work/tasks_by_type',
            params: {
              ...cycleAnalyticsRequestParams,
              subject: TASKS_BY_TYPE_SUBJECT_MERGE_REQUEST,
              label_names: groupLabelNames,
            },
          }),
        );
      });
    });
  });

  describe('when fetch top labels returns 200 with a data error', () => {
    beforeEach(() => {
      mock
        .onGet(endpoints.tasksByTypeTopLabelsData)
        .replyOnce(HTTP_STATUS_OK, { error: 'Too much data' });
      return createWrapper();
    });

    it('does not show an alert', () => {
      expect(createAlert).not.toHaveBeenCalled();
    });

    it('does not request tasks by type', () => {
      expect(mock.history.get).toHaveLength(1);
      expect(mock.history.get[0]).toEqual(
        expect.objectContaining({
          url: '/fake/group/path/-/analytics/type_of_work/tasks_by_type/top_labels',
        }),
      );
    });
  });

  describe('when fetch top labels throws an error', () => {
    beforeEach(() => {
      mock
        .onGet(endpoints.tasksByTypeTopLabelsData)
        .replyOnce(HTTP_STATUS_NOT_FOUND, { error: 'error' });
      return createWrapper();
    });

    it('shows an error alert', () => {
      expect(createAlert).toHaveBeenCalledWith({
        message: 'There was an error fetching the top labels for the selected group',
      });
    });

    it('does not request tasks by type', () => {
      expect(mock.history.get).toHaveLength(1);
      expect(mock.history.get[0]).toEqual(
        expect.objectContaining({
          url: '/fake/group/path/-/analytics/type_of_work/tasks_by_type/top_labels',
        }),
      );
    });

    it('passes an error message to the type of work charts', () => {
      expect(findTypeOfWorkCharts().props().errorMessage).toEqual(
        'Request failed with status code 404',
      );
    });
  });

  describe('when tasks by type returns 200 with a data error', () => {
    beforeEach(() => {
      mock.onGet(endpoints.tasksByTypeTopLabelsData).replyOnce(HTTP_STATUS_OK, groupLabels);
      mock.onGet(endpoints.tasksByTypeData).replyOnce(HTTP_STATUS_OK, { error: 'Too much data' });
      return createWrapper();
    });

    it('does not show an alert', () => {
      expect(createAlert).not.toHaveBeenCalled();
    });
  });

  describe('when tasks by type throws an error', () => {
    beforeEach(() => {
      mock.onGet(endpoints.tasksByTypeTopLabelsData).replyOnce(HTTP_STATUS_OK, groupLabels);
      mock.onGet(endpoints.tasksByTypeData).replyOnce(HTTP_STATUS_NOT_FOUND, { error: 'error' });
      return createWrapper();
    });

    it('shows an error alert', () => {
      expect(createAlert).toHaveBeenCalledWith({
        message: 'There was an error fetching data for the tasks by type chart',
      });
    });
  });
});
