import AnonUsersFilter from './anon_users_filter.vue';

export default {
  component: AnonUsersFilter,
  title: 'ee/analytics/analytics_dashboards/components/filters/anon_users_filter',
};

const Template = (args, { argTypes }) => ({
  components: { AnonUsersFilter },
  props: Object.keys(argTypes),
  template: `<anon-users-filter v-bind="$props" />`,
});

export const Default = Template.bind({});
Default.args = {
  value: true,
};
