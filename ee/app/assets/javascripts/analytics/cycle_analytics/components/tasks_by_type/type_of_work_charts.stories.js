import { withVuexStore } from 'storybook_addons/vuex_store';
import createMockApollo from 'helpers/mock_apollo_helper';
import TypeOfWorkCharts from './type_of_work_charts.vue';
import { tasksByTypeChartData } from './stories_constants';

export default {
  component: TypeOfWorkCharts,
  title: 'ee/analytics/cycle_analytics/components/type_of_work_charts',
  decorators: [withVuexStore],
};

const mockApolloProvider = () => createMockApollo();

const createStoryWithState = () => {
  return (args, { argTypes, createVuexStore }) => ({
    components: { TypeOfWorkCharts },
    apolloProvider: mockApolloProvider(),
    props: Object.keys(argTypes),
    template: '<type-of-work-charts v-bind="$props" />',
    store: createVuexStore({
      state: {
        namespace: { name: 'Some namespace' },
        createdAfter: new Date('2023-01-01'),
        createdBefore: new Date('2023-12-31'),
      },
      getters: {
        selectedProjectIds: () => [],
      },
    }),
  });
};

export const Default = createStoryWithState().bind({});
Default.args = { chartData: tasksByTypeChartData };

export const NoData = createStoryWithState().bind({});
NoData.args = { chartData: { data: [] } };

export const ErrorMessage = createStoryWithState().bind({});
ErrorMessage.args = { chartData: { data: [] }, errorMessage: 'Failed to load chart' };
