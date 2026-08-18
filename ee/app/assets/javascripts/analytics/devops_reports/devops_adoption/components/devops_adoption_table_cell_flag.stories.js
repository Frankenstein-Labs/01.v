import DevopsAdoptionTableCellFlag from './devops_adoption_table_cell_flag.vue';

export default {
  component: DevopsAdoptionTableCellFlag,
  title: 'ee/analytics/devops_reports/devops_adoption/components/devops_adoption_table_cell_flag',
};

const Template = (args, { argTypes }) => ({
  components: { DevopsAdoptionTableCellFlag },
  props: Object.keys(argTypes),
  template: `<devops-adoption-table-cell-flag v-bind="$props" />`,
});

const defaultArgs = {
  enabled: true,
  withText: true,
};

export const Default = Template.bind({});
Default.args = defaultArgs;

export const WithoutText = Template.bind({});
WithoutText.args = {
  ...defaultArgs,
  withText: false,
};

export const NotEnabled = Template.bind({});
NotEnabled.args = {
  ...defaultArgs,
  enabled: false,
};

export const NotEnabledWithoutText = Template.bind({});
NotEnabledWithoutText.args = {
  enabled: false,
  withText: false,
};
