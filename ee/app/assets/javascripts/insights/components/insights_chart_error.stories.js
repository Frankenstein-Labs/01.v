import InsightsChartError from './insights_chart_error.vue';

export default {
  component: InsightsChartError,
  title: 'ee/insights/components/insights_chart_error.vue',
};

const createStory = ({ ...options } = {}) => {
  return (_, { argTypes }) => {
    return {
      components: { InsightsChartError },
      props: Object.keys(argTypes),
      template: '<insights-chart-error v-bind="$props" />',
      ...options,
    };
  };
};

const defaultProps = {
  title: 'Chart title',
  error: 'Failed to load the data',
  chartName: 'MR types',
  summary: 'There was a problem loading the chart data',
};

export const Default = createStory();
Default.args = defaultProps;
