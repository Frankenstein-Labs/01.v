import { withVuexStore } from 'storybook_addons/vuex_store';
import { TEST_HOST } from 'helpers/test_constants';
import {
  pageInfo,
  pageInfoNoCharts,
  createLoadingChartData,
  createLoadedChartData,
} from 'ee_jest/insights/mock_data';
import InsightsPage from './insights_page.vue';

export default {
  component: InsightsPage,
  title: 'ee/insights/components/insights_page.vue',
  decorators: [withVuexStore],
};

const createStoryWithState = ({ state, ...options } = {}) => {
  return (_, { argTypes, createVuexStore }) => {
    return {
      components: { InsightsPage },
      props: Object.keys(argTypes),
      template: '<insights-page v-bind="$props" />',
      store: createVuexStore({
        modules: {
          insights: {
            namespaced: true,
            state: {
              chartData: createLoadedChartData(),
              ...state,
            },
            actions: {
              initChartData: () => {},
              fetchChartData: () => {},
            },
          },
        },
      }),
      ...options,
    };
  };
};

const defaultProps = {
  queryEndpoint: `${TEST_HOST}/query`,
  pageConfig: pageInfo,
};

export const Default = createStoryWithState();
Default.args = defaultProps;

export const WithNoChartsConfigured = createStoryWithState();
WithNoChartsConfigured.args = {
  ...defaultProps,
  pageConfig: pageInfoNoCharts,
};

export const Loading = createStoryWithState({ state: { chartData: createLoadingChartData() } });
Loading.args = defaultProps;
