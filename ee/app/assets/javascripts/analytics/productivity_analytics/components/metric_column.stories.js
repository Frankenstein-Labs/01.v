import MetricColumn from './metric_column.vue';

export default {
  component: MetricColumn,
  title: 'ee/analytics/productivity_analytics/components/metric_column',
};

const Template = (args, { argTypes }) => ({
  components: { MetricColumn },
  props: Object.keys(argTypes),
  template: `
    <metric-column v-bind="$props" />`,
});

const defaultArgs = {
  type: 'days_to_merge',
  value: 10,
  label: 'Fake metric column',
};

export const Default = Template.bind({});
Default.args = {
  ...defaultArgs,
};

export const NoValue = Template.bind({});
NoValue.args = {
  ...defaultArgs,
  value: null,
};

export const NoLabel = Template.bind({});
NoLabel.args = {
  ...defaultArgs,
  label: '',
};
