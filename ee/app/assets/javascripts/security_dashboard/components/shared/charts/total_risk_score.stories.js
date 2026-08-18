import { makeContainer } from 'storybook_addons/make_container';
import '../../../../../stylesheets/page_bundles/security_dashboard.scss';
import TotalRiskScore from './total_risk_score.vue';
import { withPinia } from './decorators';

export default {
  component: TotalRiskScore,
  title: 'ee/security_dashboard/charts/total_risk_score',
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
  argTypes: {
    score: {
      control: {
        type: 'range',
        min: 0,
        max: 100,
        step: 1,
      },
      description: 'The risk score value to display',
    },
  },
};

const Template = (args, { argTypes }) => ({
  components: { TotalRiskScore },
  props: Object.keys(argTypes),
  template: '<total-risk-score v-bind="$props" style="min-width: 300px; min-height: 300px;" />',
});

export const Default = Template.bind({});
Default.args = {
  score: 50,
};
