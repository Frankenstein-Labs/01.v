import { shallowMount } from '@vue/test-utils';
import { GlAlert } from '@gitlab/ui';
import Vue from 'vue';
// eslint-disable-next-line no-restricted-imports
import Vuex from 'vuex';
import waitForPromises from 'helpers/wait_for_promises';
import TasksByTypeChart from 'ee/analytics/cycle_analytics/components/tasks_by_type/chart.vue';
import TasksByTypeFilters from 'ee/analytics/cycle_analytics/components/tasks_by_type/filters.vue';
import TypeOfWorkCharts from 'ee/analytics/cycle_analytics/components/tasks_by_type/type_of_work_charts.vue';
import NoDataAvailableState from 'ee/analytics/cycle_analytics/components/no_data_available_state.vue';
import {
  TASKS_BY_TYPE_SUBJECT_MERGE_REQUEST,
  TASKS_BY_TYPE_SUBJECT_ISSUE,
} from 'ee/analytics/cycle_analytics/constants';
import { tasksByTypeData, groupLabelNames } from '../../mock_data';

Vue.use(Vuex);

describe('TypeOfWorkCharts', () => {
  let wrapper;

  const createStore = (state, rootGetters) =>
    new Vuex.Store({
      state: {
        namespace: {
          name: 'Gitlab Org',
        },
        createdAfter: new Date('2019-12-11'),
        createdBefore: new Date('2020-01-10'),
      },
      getters: {
        selectedProjectIds: () => [],
        ...rootGetters,
      },
    });

  const createWrapper = ({ state = {}, rootGetters = {}, props = {} } = {}) => {
    wrapper = shallowMount(TypeOfWorkCharts, {
      store: createStore(state, rootGetters),
      stubs: {
        TasksByTypeChart: true,
        TasksByTypeFilters: true,
      },
      propsData: {
        chartData: tasksByTypeData,
        subject: TASKS_BY_TYPE_SUBJECT_ISSUE,
        selectedLabelNames: groupLabelNames,
        ...props,
      },
    });

    return waitForPromises();
  };

  const findSubjectFilters = () => wrapper.findComponent(TasksByTypeFilters);
  const findTasksByTypeChart = () => wrapper.findComponent(TasksByTypeChart);
  const findNoDataAvailableState = () => wrapper.findComponent(NoDataAvailableState);
  const findErrorAlert = () => wrapper.findComponent(GlAlert);

  describe('with data', () => {
    beforeEach(() => {
      createWrapper();
    });

    it('renders the task by type chart', () => {
      expect(findTasksByTypeChart().props()).toEqual({
        data: tasksByTypeData.data,
        groupBy: tasksByTypeData.groupBy,
      });
    });

    it('renders a description of the current filters', () => {
      expect(wrapper.text()).toContain(
        "Shows issues and 3 labels for group 'Gitlab Org' from Dec 11, 2019 to Jan 10, 2020",
      );
    });

    it('renders the subject filters', () => {
      expect(findSubjectFilters().props()).toEqual(
        expect.objectContaining({
          selectedLabelNames: groupLabelNames,
          subjectFilter: TASKS_BY_TYPE_SUBJECT_ISSUE,
        }),
      );
    });

    it('emits `set-subject` when a subject is selected', () => {
      findSubjectFilters().vm.$emit('set-subject', TASKS_BY_TYPE_SUBJECT_MERGE_REQUEST);

      expect(wrapper.emitted('set-subject')[0][0]).toEqual(TASKS_BY_TYPE_SUBJECT_MERGE_REQUEST);
    });

    it('emits `toggle-label` when a label is selected', () => {
      const testLabel = 'mylabel';

      findSubjectFilters().vm.$emit('toggle-label', testLabel);

      expect(wrapper.emitted('toggle-label')[0][0]).toEqual(testLabel);
    });
  });

  describe('with selected projects', () => {
    it('renders multiple selected project counts', () => {
      createWrapper({ rootGetters: { selectedProjectIds: () => [1, 2] } });

      expect(wrapper.text()).toContain(
        "Shows issues and 3 labels for group 'Gitlab Org' and 2 projects from Dec 11, 2019 to Jan 10, 2020",
      );
    });

    it('renders one selected project count', () => {
      createWrapper({ rootGetters: { selectedProjectIds: () => [1] } });

      expect(wrapper.text()).toContain(
        "Shows issues and 3 labels for group 'Gitlab Org' and 1 project from Dec 11, 2019 to Jan 10, 2020",
      );
    });
  });

  describe('with no data', () => {
    beforeEach(() => {
      createWrapper({ props: { chartData: { data: [] } } });
    });

    it('does not renders the task by type chart', () => {
      expect(findTasksByTypeChart().exists()).toBe(false);
    });

    it('renders the no data available message', () => {
      expect(findNoDataAvailableState().exists()).toBe(true);
    });
  });

  describe('with errorMessage', () => {
    const errorMessage = 'whoopsie!';

    beforeEach(() => {
      createWrapper({ props: { chartData: { data: [] }, errorMessage } });
    });

    it('shows the message in an error alert', () => {
      expect(findErrorAlert().text()).toEqual(errorMessage);
    });
  });
});
