import { makeContainer } from 'storybook_addons/make_container';
import VulnerabilitiesByAgeChart from './vulnerabilities_by_age_chart.vue';
import { withPinia } from './decorators';

export default {
  component: VulnerabilitiesByAgeChart,
  title: 'ee/security_dashboard/charts/vulnerabilities_by_age_chart',
  decorators: [
    withPinia,
    makeContainer({
      width: '600px',
      height: '400px',
      resize: 'both',
      overflow: 'auto',
      boxSizing: 'border-box',
      border: '1px solid var(--gray-200, #e5e5e5)',
    }),
  ],
};

const Template = (args, { argTypes }) => ({
  components: { VulnerabilitiesByAgeChart },
  props: Object.keys(argTypes),
  provide: { securityVulnerabilitiesPath: '/security/vulnerabilities' },
  template: `<vulnerabilities-by-age-chart v-bind="$props" />`,
});

export const Default = Template.bind({});
Default.args = {
  labels: ['< 30 days', '30–60 days', '61–90 days', '91–120 days', '> 120 days'],
  bars: [
    { name: 'Critical', id: 'critical', data: [3, 5, 8, 6, 4] },
    { name: 'High', id: 'high', data: [8, 12, 15, 10, 7] },
    { name: 'Medium', id: 'medium', data: [15, 20, 18, 14, 9] },
    { name: 'Low', id: 'low', data: [20, 25, 22, 18, 12] },
    { name: 'Info', id: 'info', data: [5, 7, 6, 4, 3] },
    { name: 'Unknown', id: 'unknown', data: [2, 3, 4, 3, 2] },
  ],
};
