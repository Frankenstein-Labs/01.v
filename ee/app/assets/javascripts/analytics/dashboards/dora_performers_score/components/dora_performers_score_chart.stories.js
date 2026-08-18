import createMockApollo from 'helpers/mock_apollo_helper';
import groupDoraPerformanceScoreCountsQuery from '../graphql/group_dora_performance_score_counts.query.graphql';
import DoraPerformersScoreChart from './dora_performers_score_chart.vue';
import {
  doraPerformanceScoreCountsSuccess,
  excludedProjectsDoraPerformanceScoreCounts,
  filterProjectTopics,
  noProjectsWithDoraPerformanceScoreCounts,
} from './stories_constants';

const defaultData = {
  namespace: 'gitlab-org',
};

export default {
  component: DoraPerformersScoreChart,
  title: 'ee/analytics/dashboards/dora_performers_score/components/dora_performers_score_chart',
};

const createStory = ({ mockApollo, requestHandler = doraPerformanceScoreCountsSuccess } = {}) => {
  const defaultApolloProvider = createMockApollo([
    [groupDoraPerformanceScoreCountsQuery, () => Promise.resolve(requestHandler)],
  ]);

  return (args, { argTypes }) => ({
    components: { DoraPerformersScoreChart },
    apolloProvider: mockApollo || defaultApolloProvider,
    provide: {
      topicsExploreProjectsPath: '',
    },
    props: Object.keys(argTypes),
    template: '<dora-performers-score-chart v-bind="$props" />',
  });
};

export const Default = {
  render: createStory(),
  args: {
    data: defaultData,
  },
};

export const WithExcludedProjectsTooltip = {
  render: createStory({
    requestHandler: excludedProjectsDoraPerformanceScoreCounts,
  }),
  args: Default.args,
};

export const WithProjectTopicsFilters = {
  render: createStory(),
  args: {
    data: {
      ...defaultData,
      filters: {
        projectTopics: filterProjectTopics,
      },
    },
  },
};

export const NoData = {
  render: createStory({
    requestHandler: noProjectsWithDoraPerformanceScoreCounts,
  }),
  args: Default.args,
};

export const Loading = {
  render: createStory({
    mockApollo: createMockApollo([
      [groupDoraPerformanceScoreCountsQuery, () => new Promise(() => {})],
    ]),
  }),
  args: Default.args,
};
