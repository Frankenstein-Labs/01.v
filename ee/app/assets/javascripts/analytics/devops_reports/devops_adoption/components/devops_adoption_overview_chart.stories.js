import createMockApollo from 'helpers/mock_apollo_helper';
import devopsAdoptionOverviewChartQuery from '../graphql/queries/devops_adoption_overview_chart.query.graphql';
import DevopsAdoptionOverviewChart from './devops_adoption_overview_chart.vue';
import { mockDevopsOverviewChartResponse } from './stories_constants';

export default {
  component: DevopsAdoptionOverviewChart,
  title: 'ee/analytics/devops_reports/devops_adoption/components/devops_adoption_overview_chart',
};

const createStory = ({ mockApollo, response = mockDevopsOverviewChartResponse } = {}) => {
  const defaultApolloProvider = createMockApollo([
    [devopsAdoptionOverviewChartQuery, () => Promise.resolve(response)],
  ]);

  return (args, { argTypes }) => ({
    components: { DevopsAdoptionOverviewChart },
    apolloProvider: mockApollo || defaultApolloProvider,
    props: Object.keys(argTypes),
    provide: {
      groupGid: 'fake-group',
    },
    template: `<devops-adoption-overview-chart v-bind="$props" />`,
  });
};

export const Default = {
  render: createStory(),
  args: {},
};

export const Loading = {
  render: createStory({
    mockApollo: createMockApollo([[devopsAdoptionOverviewChartQuery, () => new Promise(() => {})]]),
  }),
  args: Default.args,
};
