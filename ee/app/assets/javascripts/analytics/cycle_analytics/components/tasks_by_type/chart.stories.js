import { tasksByTypeChartData } from './stories_constants';
import TasksByTypeChart from './chart.vue';

export default {
  component: TasksByTypeChart,
  title: 'ee/analytics/cycle_analytics/components/tasks_by_type/chart',
};

const Template = (args, { argTypes }) => ({
  components: { TasksByTypeChart },
  props: Object.keys(argTypes),
  template: '<tasks-by-type-chart v-bind="$props" />',
});

const { data, groupBy } = tasksByTypeChartData;

export const Default = Template.bind({});
Default.args = {
  data,
  groupBy,
};
