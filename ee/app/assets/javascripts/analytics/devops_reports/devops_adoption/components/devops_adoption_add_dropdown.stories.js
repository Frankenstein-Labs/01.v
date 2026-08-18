import { mockDevopsAdoptionNamespace } from './stories_constants';
import DevopsAdoptionAddDropdown from './devops_adoption_add_dropdown.vue';

export default {
  component: DevopsAdoptionAddDropdown,
  title: 'ee/analytics/devops_reports/devops_adoption/components/devops_adoption_add_dropdown',
};

const Template = (args, { argTypes }) => ({
  components: { DevopsAdoptionAddDropdown },
  props: Object.keys(argTypes),
  provide: {
    isGroup: true,
    groupGid: 'fake',
  },
  template: `<devops-adoption-add-dropdown v-bind="$props" />`,
});

const mockGroups = [
  {
    id: 411,
    full_name: 'Fake / fake-subgroup-for-testing',
  },
  {
    id: 419,
    full_name: 'Fake group',
  },
];

const defaultArgs = {
  searchTerm: null,
  isLoadingGroups: false,
  hasSubgroups: true,
  groups: mockGroups,
  enabledNamespace: mockDevopsAdoptionNamespace,
};

export const Default = Template.bind({});
Default.args = defaultArgs;

export const NoSubgroups = Template.bind({});
NoSubgroups.args = { ...defaultArgs, hasSubgroups: false };

export const IsLoading = Template.bind({});
IsLoading.args = { ...defaultArgs, isLoadingGroups: true };
