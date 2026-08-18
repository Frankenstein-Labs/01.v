import { withVuexStore } from 'storybook_addons/vuex_store';
import IssuesAnalyticsChart from './issues_analytics_chart.vue';
import { mockIssueAnalyticsChartData } from './stories_constants';

export default {
  component: IssuesAnalyticsChart,
  title: 'ee/issues_analytics/components/issues_analytics_chart',
  decorators: [withVuexStore],
};

const createStoryWithState = ({ state = {} }) => {
  return (args, { argTypes, createVuexStore }) => ({
    components: { IssuesAnalyticsChart },
    props: Object.keys(argTypes),
    template: '<issues-analytics-chart v-bind="$props" />',
    store: createVuexStore({
      modules: {
        issueAnalytics: {
          namespaced: true,
          state: {
            loading: false,
            chartData: mockIssueAnalyticsChartData,
            ...state,
          },
          getters: {
            hasFilters: () => false,
            appliedFilters: () => [],
          },
          actions: {
            fetchChartData: () => {},
          },
        },
      },
    }),
  });
};

const defaultState = {};
export const Default = createStoryWithState(defaultState).bind({});

const loadingState = { state: { loading: true } };
export const Loading = createStoryWithState(loadingState).bind({});

const noDataState = { state: { chartData: {} } };
export const NoData = createStoryWithState(noDataState).bind({});
