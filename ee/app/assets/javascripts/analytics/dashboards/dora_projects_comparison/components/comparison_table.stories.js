import DashboardLayout from 'storybook_helpers/dashboards/dashboard_layout.vue';
import { daysToSeconds } from '~/lib/utils/datetime/date_calculation_utility';
import ComparisonTable from './comparison_table.vue';

export default {
  title: 'ee/analytics/dashboards/dora_projects_comparison/comparison_table',
  component: ComparisonTable,
};

const Template = (args, { argTypes }) => ({
  props: Object.keys(argTypes),
  components: { ComparisonTable },
  template: '<comparison-table v-bind="$props" />',
});

const WithDashboard = (args, { argTypes }) => ({
  components: { ComparisonTable, DashboardLayout },
  props: Object.keys(argTypes),
  template: `
      <dashboard-layout :panels="panelsConfig">
        <comparison-table v-bind="$props" />
      </dashboard-layout>`,
});

const defaultArgs = {
  projects: [
    {
      id: 'gid://gitlab/Project/20',
      name: 'dashboards',
      avatarUrl: null,
      webUrl: 'http://gdk.test:3000/flightjs/Flight',
      trends: {
        deployment_frequency: -0.27,
        lead_time_for_changes: 0.42,
        time_to_restore_service: 1,
        change_failure_rate: -0.25,
      },
      __typename: 'DoraMetric',
      date: '2024-10-01',
      deployment_frequency: 1.16,
      change_failure_rate: 0.41,
      lead_time_for_changes: daysToSeconds(6),
      time_to_restore_service: daysToSeconds(0.2),
    },
    {
      id: 'gid://gitlab/Project/19',
      name: 'catalog',
      avatarUrl: null,
      webUrl: 'http://gdk.test:3000/flightjs/Flight',
      trends: {
        deployment_frequency: -0.58,
        lead_time_for_changes: 0.17,
        time_to_restore_service: 0.33,
        change_failure_rate: -0.16,
      },
      __typename: 'DoraMetric',
      date: '2024-10-01',
      deployment_frequency: 0.38,
      change_failure_rate: 0.41,
      lead_time_for_changes: daysToSeconds(2),
      time_to_restore_service: daysToSeconds(0.5),
    },
    {
      id: 'gid://gitlab/Project/7',
      name: 'Flight',
      avatarUrl: null,
      webUrl: 'http://gdk.test:3000/flightjs/Flight',
      trends: {
        deployment_frequency: -0.44,
        lead_time_for_changes: 1.5,
        time_to_restore_service: -0.33,
        change_failure_rate: -0.2,
      },
      __typename: 'DoraMetric',
      date: '2024-10-01',
      deployment_frequency: 0.387,
      change_failure_rate: 0.41,
      lead_time_for_changes: daysToSeconds(5),
      time_to_restore_service: daysToSeconds(0.7),
    },
  ],
};

export const Default = Template.bind({});
Default.args = defaultArgs;

export const NoData = Template.bind({});
NoData.args = { projects: [] };

export const InDashboardPanel = WithDashboard.bind({});
InDashboardPanel.args = {
  ...defaultArgs,
  panelsConfig: [
    {
      id: '1',
      title: 'DORA metrics projects comparison',
      gridAttributes: {
        yPos: 0,
        xPos: 0,
        width: 12,
        height: 4,
      },
    },
  ],
};
