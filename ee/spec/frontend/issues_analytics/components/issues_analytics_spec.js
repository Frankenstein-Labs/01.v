import Vue from 'vue';
// eslint-disable-next-line no-restricted-imports
import Vuex from 'vuex';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import IssuesAnalytics from 'ee/issues_analytics/components/issues_analytics.vue';
import IssuesAnalyticsChart from 'ee/issues_analytics/components/issues_analytics_chart.vue';
import TotalIssuesAnalyticsChart from 'ee/issues_analytics/components/total_issues_analytics_chart.vue';
import IssuesAnalyticsTable from 'ee/issues_analytics/components/issues_analytics_table.vue';
import { createStore } from 'ee/issues_analytics/stores';
import { useFakeDate } from 'helpers/fake_date';
import { createAlert, VARIANT_WARNING } from '~/alert';

const mockFilterManagerSetup = jest.fn();
jest.mock('ee/issues_analytics/filtered_search_issues_analytics', () =>
  jest.fn().mockImplementation(() => ({
    setup: mockFilterManagerSetup,
  })),
);
jest.mock('~/alert');

Vue.use(Vuex);

describe('IssuesAnalytics', () => {
  useFakeDate(2023, 7, 18);

  const TEST_END_DATE = new Date(2023, 7, 18);
  const TEST_START_DATE = new Date('2022-08-01T00:00:00.000Z');
  const TEST_MONTHS_BACK_START_DATE = new Date('2023-05-01T00:00:00.000Z');
  const TEST_MONTHS_BACK = 3;

  let wrapper;
  let store;

  const findIssuesAnalyticsChart = () => wrapper.findComponent(IssuesAnalyticsChart);
  const findTotalIssuesAnalyticsChart = () => wrapper.findComponent(TotalIssuesAnalyticsChart);
  const findIssuesAnalyticsTable = () => wrapper.findComponent(IssuesAnalyticsTable);

  const createComponent = ({
    props = {},
    provide = {},
    hasIssuesCompletedFeature = false,
  } = {}) => {
    const filterBlockEl = document.querySelector('#mock-filter');

    store = createStore();

    wrapper = shallowMountExtended(IssuesAnalytics, {
      propsData: {
        filterBlockEl,
        ...props,
      },
      provide: {
        hasIssuesCompletedFeature,
        ...provide,
      },
      store,
    });
  };

  const mockOriginalFilters = {
    label_name: [],
    assignee_username: [],
    author_username: 'bob',
    'not[assignee_username]': [],
  };
  const mockFilters = {
    assigneeUsernames: [],
    authorUsername: 'bob',
    not: { assigneeUsernames: [] },
  };

  describe('default', () => {
    beforeEach(() => {
      createComponent();
    });

    it('does not render raw text search alert', () => {
      expect(createAlert).not.toHaveBeenCalled();
    });

    describe('table', () => {
      it('renders the Issues Analytics table', () => {
        expect(findIssuesAnalyticsTable().props()).toEqual({
          endDate: TEST_END_DATE,
          filters: {},
          hasCompletedIssues: false,
          startDate: TEST_START_DATE,
        });
      });

      it('passes transformed global page filters to the `filters` prop', async () => {
        await store.dispatch('issueAnalytics/setFilters', mockOriginalFilters);

        expect(findIssuesAnalyticsTable().props('filters')).toEqual({
          labelName: [],
          ...mockFilters,
        });
      });
    });

    describe('when raw text search is attempted', () => {
      beforeEach(async () => {
        await store.dispatch('issueAnalytics/setFilters', { search: 'hello' });
      });

      it('should render an alert', () => {
        expect(createAlert).toHaveBeenCalledTimes(1);
        expect(createAlert).toHaveBeenCalledWith({
          message: 'Raw text search is not supported. Please use the available filters.',
          variant: VARIANT_WARNING,
        });
      });
    });
  });

  describe('chart', () => {
    it.each`
      hasIssuesCompletedFeature | shouldShowTotalIssuesAnalyticsChart | shouldShowIssuesAnalyticsChart
      ${true}                   | ${true}                             | ${false}
      ${false}                  | ${false}                            | ${true}
    `(
      'renders the correct chart component when hasIssuesCompletedFeature=$hasIssuesCompletedFeature',
      ({
        hasIssuesCompletedFeature,
        shouldShowTotalIssuesAnalyticsChart,
        shouldShowIssuesAnalyticsChart,
      }) => {
        createComponent({
          hasIssuesCompletedFeature,
        });

        expect(findTotalIssuesAnalyticsChart().exists()).toBe(shouldShowTotalIssuesAnalyticsChart);
        expect(findIssuesAnalyticsChart().exists()).toBe(shouldShowIssuesAnalyticsChart);
      },
    );
  });

  describe('when completed issues analytics are supported', () => {
    beforeEach(() => {
      createComponent({
        hasIssuesCompletedFeature: true,
      });
    });

    it('sets table `hasCompletedIssues` prop to true', () => {
      expect(findIssuesAnalyticsTable().props('hasCompletedIssues')).toBe(true);
    });

    describe('chart', () => {
      it('renders Total Issues Analytics chart', () => {
        expect(findTotalIssuesAnalyticsChart().props()).toEqual({
          endDate: TEST_END_DATE,
          filters: {},
          startDate: TEST_START_DATE,
        });
      });

      it('passes transformed global page filters to the `filters` prop', async () => {
        await store.dispatch('issueAnalytics/setFilters', mockOriginalFilters);

        expect(findTotalIssuesAnalyticsChart().props('filters')).toEqual({
          labelNames: [],
          ...mockFilters,
        });
      });
    });

    describe('when `months_back` filter is applied', () => {
      beforeEach(async () => {
        await store.dispatch('issueAnalytics/setFilters', { months_back: TEST_MONTHS_BACK });
      });

      it('updates `startDate` for table', () => {
        expect(findIssuesAnalyticsTable().props('startDate')).toEqual(TEST_MONTHS_BACK_START_DATE);
      });

      it('updates `startDate` for chart', () => {
        expect(findTotalIssuesAnalyticsChart().props('startDate')).toEqual(
          TEST_MONTHS_BACK_START_DATE,
        );
      });
    });
  });
});
