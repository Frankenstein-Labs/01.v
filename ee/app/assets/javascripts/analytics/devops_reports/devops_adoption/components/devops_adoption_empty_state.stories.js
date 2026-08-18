import DevopsAdoptionEmptyState from './devops_adoption_empty_state.vue';

export default {
  component: DevopsAdoptionEmptyState,
  title: 'ee/analytics/devops_reports/devops_adoption/components/devops_adoption_empty_state',
};

const Template = (args, { argTypes }) => ({
  components: { DevopsAdoptionEmptyState },
  props: Object.keys(argTypes),
  template: `<devops-adoption-empty-state v-bind="$props" />`,
});

const defaultArgs = {};

export const Default = Template.bind({});
Default.args = defaultArgs;
