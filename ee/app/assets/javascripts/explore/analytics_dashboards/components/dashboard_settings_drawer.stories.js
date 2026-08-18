import { GlButton } from '@gitlab/ui';
import DashboardSettingsDrawer from './dashboard_settings_drawer.vue';

export default {
  component: DashboardSettingsDrawer,
  title: 'ee/explore/analytics_dashboards/dashboard_settings_drawer',
};

const Template = (args, { argTypes }) => ({
  components: { DashboardSettingsDrawer, GlButton },
  props: Object.keys(argTypes),
  data() {
    return {
      isDrawerOpen: false,
      currentConfig: this.dashboardConfig,
    };
  },
  provide: {
    exploreAnalyticsDashboardsPath: '/explore/analytics_dashboards',
  },
  template: `
    <div class="gl-min-h-31">
      <gl-button @click="isDrawerOpen = true">Open Settings</gl-button>
      <dashboard-settings-drawer
        :open="isDrawerOpen"
        v-bind="$props"
        :dashboard-config="currentConfig"
        @update="currentConfig = $event"
        @close="isDrawerOpen = false"
      />
    </div>
  `,
});

const defaultArgs = {
  dashboardId: '1',
  dashboardConfig: {
    title: 'Sample Dashboard',
    description: 'This is a sample dashboard for testing',
  },
};

export const Default = Template.bind({});
Default.args = defaultArgs;
