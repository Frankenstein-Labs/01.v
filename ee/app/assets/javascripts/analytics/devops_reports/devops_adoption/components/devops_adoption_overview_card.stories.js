import DevopsAdoptionOverviewCard from './devops_adoption_overview_card.vue';

export default {
  component: DevopsAdoptionOverviewCard,
  title: 'ee/analytics/devops_reports/devops_adoption/components/devops_adoption_overview_card',
};

const Template = (args, { argTypes }) => ({
  components: { DevopsAdoptionOverviewCard },
  props: Object.keys(argTypes),
  template: `<devops-adoption-overview-card v-bind="$props" />`,
});

const defaultArgs = {
  title: 'Dev',
  icon: 'code',
  displayMeta: true,
  featureMeta: [
    {
      title: 'Approvals',
      adopted: false,
    },
    {
      title: 'Code owners',
      adopted: true,
    },
    {
      title: 'Issues',
      adopted: true,
    },
    {
      title: 'MRs',
      adopted: true,
    },
  ],
};

export const Default = Template.bind({});
Default.args = defaultArgs;

export const NoFeaturesAdopted = Template.bind({});
NoFeaturesAdopted.args = {
  ...defaultArgs,
  featureMeta: [
    {
      title: 'Approvals',
      adopted: false,
    },
    {
      title: 'Code owners',
      adopted: false,
    },
    {
      title: 'Issues',
      adopted: false,
    },
    {
      title: 'MRs',
      adopted: false,
    },
  ],
};

export const NoFeatures = Template.bind({});
NoFeatures.args = {
  ...defaultArgs,
  featureMeta: [],
};

export const NoDisplayMeta = Template.bind({});
NoDisplayMeta.args = {
  ...defaultArgs,
  displayMeta: false,
};
