import { GlButton } from '@gitlab/ui';
import AddPanelDrawer from './add_panel_drawer.vue';

export default {
  component: AddPanelDrawer,
  title: 'ee/explore/analytics_dashboards/add_panel_drawer',
};

const Template = (args, { argTypes }) => ({
  components: { AddPanelDrawer, GlButton },
  props: Object.keys(argTypes),
  data() {
    return {
      isDrawerOpen: false,
    };
  },
  template: `
    <div class="gl-min-h-31">
      <gl-button @click="isDrawerOpen = true">Add panel</gl-button>
      <add-panel-drawer
        :open="isDrawerOpen"
        v-bind="$props"
        @close="isDrawerOpen = false"
      />
    </div>
  `,
});

export const Default = Template.bind({});
Default.args = {};
