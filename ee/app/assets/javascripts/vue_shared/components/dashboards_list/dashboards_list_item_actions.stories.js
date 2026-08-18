import DashboardsListItemActions from './dashboards_list_item_actions.vue';

export default {
  component: DashboardsListItemActions,
  title: 'ee/vue_shared/components/dashboards_list/dashboards_list_item_actions',
};

const Template = (args) => ({
  components: { DashboardsListItemActions },
  setup() {
    return { args };
  },
  template: '<div class="gl-min-h-20"><dashboards-list-item-actions v-bind="args" /></div>',
});

export const Default = Template.bind({});
Default.args = {
  id: '1',
  system: false,
  dashboardUrl: '/dashboards/my-dashboard',
  actionLabel: 'Actions',
};

export const SystemDashboard = Template.bind({});
SystemDashboard.args = {
  id: '2',
  system: true,
  dashboardUrl: '/dashboards/system-dashboard',
  actionLabel: 'Actions',
};

export const CustomDashboard = Template.bind({});
CustomDashboard.args = {
  id: '3',
  system: false,
  dashboardUrl: '/dashboards/custom-dashboard',
  actionLabel: 'More options',
};
