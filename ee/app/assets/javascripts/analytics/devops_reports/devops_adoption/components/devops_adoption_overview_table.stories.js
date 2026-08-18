import { mockDevopsAdoptionNamespace } from './stories_constants';
import DevopsAdoptionOverviewTable from './devops_adoption_overview_table.vue';

const mockTableData = {
  __typename: 'DevopsAdoptionEnabledNamespaceConnection',
  nodes: [mockDevopsAdoptionNamespace],
};

const mockTableNoData = {
  __typename: 'DevopsAdoptionEnabledNamespaceConnection',
  nodes: [],
};

export default {
  component: DevopsAdoptionOverviewTable,
  title: 'ee/analytics/devops_reports/devops_adoption/components/devops_adoption_overview_table',
};

const Template = (args, { argTypes }) => ({
  components: { DevopsAdoptionOverviewTable },
  props: Object.keys(argTypes),
  provide: {
    groupGid: 'fake-group',
  },
  template: `<devops-adoption-overview-table v-bind="$props" />`,
});

const defaultArgs = {
  data: mockTableData,
};

export const Default = Template.bind({});
Default.args = defaultArgs;

export const NoData = Template.bind({});
NoData.args = {
  data: mockTableNoData,
};
