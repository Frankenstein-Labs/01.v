import PushesChart from './pushes_chart.vue';

export default {
  component: PushesChart,
  title: 'ee/analytics/contribution_analytics/components/pushes_chart',
};

const Template = (args, { argTypes }) => ({
  components: { PushesChart },
  props: Object.keys(argTypes),
  template: '<pushes-chart v-bind="$props" />',
});

const args = {
  pushes: [
    { user: 'Mario', count: 100 },
    { user: 'Luigi', count: 4 },
    { user: 'Peach', count: 150 },
    { user: 'Yoshi', count: 77 },
    { user: 'Bowser', count: 8 },
    { user: 'Donkey Kong', count: 101 },
    { user: 'Toad', count: 10 },
  ],
};

export const Default = Template.bind({});
Default.args = args;
