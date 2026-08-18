import InsightsChart from './insights_chart.vue';
import { defaultArguments, labelledData, noData } from './stories_constants';

export default {
  component: InsightsChart,
  title: 'ee/insights/components/insights_chart.vue',
};

const createStory = ({ ...options } = {}) => {
  return (_, { argTypes }) => {
    return {
      components: { InsightsChart },
      props: Object.keys(argTypes),
      template: '<insights-chart v-bind="$props" />',
      ...options,
    };
  };
};

export const Default = createStory();
Default.args = defaultArguments;

export const Loading = createStory();
Loading.args = {
  ...defaultArguments,
  loaded: false,
};

export const NoData = createStory();
NoData.args = noData;

export const WithTitleAndDescription = createStory();
WithTitleAndDescription.args = {
  ...defaultArguments,
  title: 'Awesome title',
  description: 'Describing the data',
};

export const WithLabels = createStory();
WithLabels.args = {
  ...labelledData,
  title: 'Bugs created by severity',
  type: 'stacked-bar',
};

export const WithError = createStory();
WithError.args = {
  ...defaultArguments,
  data: {},
  title: 'Cool chart',
  error: 'Failed to load',
};
