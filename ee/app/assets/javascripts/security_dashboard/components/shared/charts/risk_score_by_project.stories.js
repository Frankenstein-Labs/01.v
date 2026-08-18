import { makeContainer } from 'storybook_addons/make_container';
import '../../../../../stylesheets/page_bundles/security_dashboard.scss';
import RiskScoreByProject from './risk_score_by_project.vue';

export default {
  component: RiskScoreByProject,
  title: 'ee/security_dashboard/charts/risk_score_by_project',
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
  argTypes: {
    numberOfItems: {
      control: { type: 'range', min: 0, max: 100, step: 1 },
      description: 'Number of risk score items to generate',
    },
  },
};

const generateRiskScores = (count) => {
  const items = [];
  const ratings = ['CRITICAL', 'HIGH', 'MEDIUM', 'LOW'];
  const scoreRanges = {
    CRITICAL: [75, 100],
    HIGH: [50, 74],
    MEDIUM: [25, 49],
    LOW: [0, 24],
  };

  for (let i = 0; i < count; i += 1) {
    const ratingIndex = Math.floor(4 * Math.random());
    const rating = ratings[ratingIndex];
    const [min, max] = scoreRanges[rating];
    const score = (min + Math.random() * (max - min)).toFixed(1);

    items.push({
      rating,
      score,
      project: {
        id: `project-${i + 1}`,
        name: `project-${rating.toLowerCase()}-${i + 1}`,
        fullPath: `gitlab-org/project-${rating.toLowerCase()}-${i + 1}`,
      },
    });
  }

  return items.sort((a, b) => b.score - a.score);
};

const Template = (args, { argTypes }) => ({
  components: { RiskScoreByProject },
  props: Object.keys(argTypes),
  computed: {
    computedRiskScores() {
      return this.riskScores || generateRiskScores(this.numberOfItems || 0);
    },
  },
  template: `<risk-score-by-project :risk-scores="computedRiskScores"  />`,
});

export const Default = Template.bind({});
Default.args = {
  numberOfItems: 15,
};
