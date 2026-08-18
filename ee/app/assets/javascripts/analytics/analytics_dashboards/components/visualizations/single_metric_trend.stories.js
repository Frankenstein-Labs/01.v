import DashboardLayout from 'storybook_helpers/dashboards/dashboard_layout.vue';
import SingleMetricTrend from './single_metric_trend.vue';

export default {
  component: SingleMetricTrend,
  title: 'ee/analytics/analytics_dashboards/components/visualizations/metric_trend',
};

const Template = (args, { argTypes }) => ({
  components: { SingleMetricTrend, DashboardLayout },
  props: Object.keys(argTypes),
  template: `<single-metric-trend :data="data" :options="options" />`,
});

const WithDashboard = (args, { argTypes }) => ({
  components: { SingleMetricTrend, DashboardLayout },
  props: Object.keys(argTypes),
  template: `
      <dashboard-layout :panels="panelsConfig">
        <single-metric-trend :data="data" :options="options" />
      </dashboard-layout>`,
});

const defaultArgs = {
  data: {
    value: 35.16,
    trend: [
      ['Mon', 10],
      ['Tue', 15],
      ['Wed', 9],
      ['Thu', 22],
      ['Fri', 29],
      ['Sat', 20],
      ['Sun', 18],
    ],
  },
  options: {
    decimalPlaces: 1,
  },
};

export const Default = Template.bind({});
Default.args = defaultArgs;

export const FlatTrend = Template.bind({});
FlatTrend.args = {
  ...defaultArgs,
  data: {
    value: 0,
    trend: [
      ['Mon', 0],
      ['Tue', 0],
      ['Wed', 0],
      ['Thu', 0],
      ['Fri', 0],
      ['Sat', 0],
      ['Sun', 0],
    ],
  },
};

export const NoTrend = Template.bind({});
NoTrend.args = {
  ...defaultArgs,
  data: {
    value: 0,
    trend: [
      ['Mon', null],
      ['Tue', null],
      ['Wed', null],
      ['Thu', null],
      ['Fri', null],
      ['Sat', null],
      ['Sun', null],
    ],
  },
};

export const InDashboardPanel = WithDashboard.bind({});
InDashboardPanel.args = {
  ...defaultArgs,
  panelsConfig: [
    {
      id: '1',
      title: 'Metric trend #1',
      gridAttributes: {
        yPos: 0,
        xPos: 0,
        width: 3,
        height: 2,
      },
    },
  ],
};
