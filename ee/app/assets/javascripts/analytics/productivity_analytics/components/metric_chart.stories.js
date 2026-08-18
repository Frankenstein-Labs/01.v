import Scatterplot from '../../shared/components/scatterplot.vue';
import MetricChart from './metric_chart.vue';
import { metricTypes, metricType } from './stories_constants';

export default {
  component: MetricChart,
  title: 'ee/analytics/productivity_analytics/components/metric_chart',
};

const Template = (args, { argTypes }) => ({
  components: { MetricChart },
  props: Object.keys(argTypes),
  template: `
    <metric-chart v-bind="$props" />`,
});

const WithScatterplot = (args, { argTypes }) => ({
  components: { MetricChart, Scatterplot },
  props: Object.keys(argTypes),
  template: `
    <metric-chart v-bind="$props">
      <scatterplot x-axis-title="X Axis label" y-axis-title="Y Axis label" :scatter-data="scatterplotMainData" />
    </metric-chart>
  `,
});

const scatterplotMainData = [
  ['2024-02-18', 24, '2024-02-18T12:08:17.000Z'],
  ['2024-02-25', 3, '2024-02-25T10:00:05.000Z'],
  ['2024-03-03', 13, '2024-03-03T11:19:55.000Z'],
];

const defaultArgs = {
  title: 'Fake metric chart',
  description: 'This is a fake metric chart, used for testing',
  isLoading: false,
  chartData: [[24, 13]],
  metricTypes,
  errorCode: null,
  selectedMetric: '',
};

export const Default = Template.bind({});
Default.args = {
  ...defaultArgs,
};

export const SelectedMetric = Template.bind({});
SelectedMetric.args = {
  ...defaultArgs,
  selectedMetric: metricType,
};

export const Loading = Template.bind({});
Loading.args = {
  ...defaultArgs,
  isLoading: true,
};

export const NoData = Template.bind({});
NoData.args = {
  ...defaultArgs,
  chartData: [],
};

export const WithChartInDefaultSlot = WithScatterplot.bind({});
WithChartInDefaultSlot.args = {
  ...defaultArgs,
  isBlob: true,
  scatterplotMainData,
};
