import MergeRequestsChart from './merge_requests_chart.vue';

export default {
  component: MergeRequestsChart,
  title: 'ee/analytics/contribution_analytics/components/merge_requests_chart',
};

const Template = (args, { argTypes }) => ({
  components: { MergeRequestsChart },
  props: Object.keys(argTypes),
  template: '<merge-requests-chart v-bind="$props" />',
});

const args = {
  mergeRequests: [
    { user: 'Mario', created: 150, closed: 10, merged: 12 },
    { user: 'Luigi', created: 140, closed: 100, merged: 34 },
    { user: 'Peach', created: 130, closed: 50, merged: 64 },
    { user: 'Yoshi', created: 110, closed: 25, merged: 143 },
    { user: 'Bowser', created: 70, closed: 125, merged: 56 },
    { user: 'Donkey Kong', created: 30, closed: 0, merged: 12 },
    { user: 'Toad', created: 10, closed: 75, merged: 10 },
  ],
};

export const Default = Template.bind({});
Default.args = args;
