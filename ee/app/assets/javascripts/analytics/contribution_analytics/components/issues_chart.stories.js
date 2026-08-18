import IssuesChart from './issues_chart.vue';

export default {
  component: IssuesChart,
  title: 'ee/analytics/contribution_analytics/components/issues_chart',
};

const Template = (args, { argTypes }) => ({
  components: { IssuesChart },
  props: Object.keys(argTypes),
  template: '<issues-chart v-bind="$props" />',
});

const args = {
  issues: [
    { user: 'Mario', created: 100, closed: 10 },
    { user: 'Luigi', created: 4, closed: 100 },
    { user: 'Peach', created: 150, closed: 50 },
    { user: 'Yoshi', created: 77, closed: 25 },
    { user: 'Bowser', created: 8, closed: 125 },
    { user: 'Donkey Kong', created: 101, closed: 0 },
    { user: 'Toad', created: 10, closed: 75 },
  ],
};

export const Default = Template.bind({});
Default.args = args;
