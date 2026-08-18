import { SEVERITY_LEVELS_KEYS } from 'ee/security_dashboard/constants';
import VulnerabilitiesForSeverityPanel from './vulnerabilities_for_severity_panel.vue';

export default {
  component: VulnerabilitiesForSeverityPanel,
  title: 'ee/security_dashboard/charts/vulnerabilities_for_severity_panel',
  argTypes: {
    severity: {
      options: SEVERITY_LEVELS_KEYS,
      control: { type: 'select' },
    },
  },
};

const Template = (args, { argTypes }) => ({
  components: { VulnerabilitiesForSeverityPanel },
  props: Object.keys(argTypes),
  template: `<vulnerabilities-for-severity-panel v-bind="$props" />`,
});

export const Default = Template.bind({});
Default.args = {
  severity: 'high',
  count: 12,
  error: false,
  loading: false,
};
