import UsageStatistics from './usage_statistics.vue';

export default {
  component: UsageStatistics,
  title: 'ee/usage_quotas/usage_statistics',
};

const Template = (_, { argTypes }) => ({
  components: { UsageStatistics },
  props: Object.keys(argTypes),
  template: `<usage-statistics v-bind="$props" />`,
});
export const Default = Template.bind({});

Default.args = {
  percentage: 80,
  usageValue: 8,
  usageUnit: 'seats',
  totalValue: 10,
  totalUnit: 'seats',
};
