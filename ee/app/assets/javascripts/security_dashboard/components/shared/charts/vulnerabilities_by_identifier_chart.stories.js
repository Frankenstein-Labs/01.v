import { makeContainer } from 'storybook_addons/make_container';
import VulnerabilitiesByIdentifierChart from './vulnerabilities_by_identifier_chart.vue';

export default {
  component: VulnerabilitiesByIdentifierChart,
  title: 'ee/security_dashboard/charts/vulnerabilities_by_identifier_chart',
  decorators: [
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
  components: { VulnerabilitiesByIdentifierChart },
  props: Object.keys(argTypes),
  provide: { securityVulnerabilitiesPath: '/security/vulnerabilities' },
  template: `<vulnerabilities-by-identifier-chart v-bind="$props" />`,
});

export const Default = Template.bind({});
Default.args = {
  vulnerabilitiesByIdentifier: [
    {
      name: 'CWE-79',
      url: 'https://cwe.mitre.org/data/definitions/79.html',
      bySeverity: [
        { count: 5, severity: 'HIGH' },
        { count: 3, severity: 'MEDIUM' },
      ],
    },
    {
      name: 'CWE-89',
      url: 'https://cwe.mitre.org/data/definitions/89.html',
      bySeverity: [
        { count: 8, severity: 'CRITICAL' },
        { count: 4, severity: 'HIGH' },
      ],
    },
    {
      name: 'CWE-22',
      url: null,
      bySeverity: [{ count: 2, severity: 'LOW' }],
    },
  ],
  filters: {},
};
