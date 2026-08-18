import MergeRequestTableRow from './mr_table_row.vue';
import { mergeRequests } from './stories_constants';

export default {
  component: MergeRequestTableRow,
  title: 'ee/analytics/productivity_analytics/components/mr_table_row',
};

const Template = (args, { argTypes }) => ({
  components: { MergeRequestTableRow },
  props: Object.keys(argTypes),
  template: `<merge-request-table-row v-bind="$props" />`,
});

const defaultArgs = {
  mergeRequest: mergeRequests[0],
  metricType: 'days_to_merge',
  metricLabel: 'Days to merge',
};

export const Default = Template.bind({});
Default.args = defaultArgs;
