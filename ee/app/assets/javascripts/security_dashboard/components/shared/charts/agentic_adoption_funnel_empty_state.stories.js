import { makeContainer } from 'storybook_addons/make_container';
import '../../../../../stylesheets/page_bundles/security_dashboard.scss';
import AgenticAdoptionFunnelEmptyState from './agentic_adoption_funnel_empty_state.vue';

export default {
  component: AgenticAdoptionFunnelEmptyState,
  title: 'ee/security_dashboard/charts/agentic_adoption_funnel_empty_state',
  decorators: [
    makeContainer({
      width: '400px',
      height: '250px',
      resize: 'both',
      overflow: 'auto',
      boxSizing: 'border-box',
    }),
  ],
  argTypes: {
    icon: { control: 'text' },
    title: { control: 'text' },
    description: { control: 'text' },
    canEnable: { control: 'boolean' },
    disabledDescription: { control: 'text' },
  },
};

const Template = (args, { argTypes }) => ({
  components: { AgenticAdoptionFunnelEmptyState },
  props: Object.keys(argTypes),
  provide: { manageDuoSettingsPath: '/settings/security' },
  template: `<agentic-adoption-funnel-empty-state v-bind="$props" />`,
});

export const CanEnable = Template.bind({});
CanEnable.args = {
  icon: 'check-circle-dashed',
  title: 'False Positive Detection turned off',
  description: 'AI evaluates for false positives, helping to tune the noise to signal ratio',
  canEnable: true,
  disabledDescription: 'Ask someone with the Maintainer or Owner role to turn it on.',
};

export const CannotEnable = Template.bind({});
CannotEnable.args = {
  icon: 'check-circle-dashed',
  title: 'False Positive Detection turned off',
  description: 'AI evaluates for false positives, helping to tune the noise to signal ratio',
  canEnable: false,
  disabledDescription: 'Ask someone with the Maintainer or Owner role to turn it on.',
};
