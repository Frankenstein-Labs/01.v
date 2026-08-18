import Vue from 'vue';
import VueApollo from 'vue-apollo';
import createMockApollo from 'helpers/mock_apollo_helper';
import getGroupTestCoverage from '../graphql/queries/get_group_test_coverage.query.graphql';
import TestCoverageSummary from './test_coverage_summary.vue';
import { groupTestCoverageResponse, groupTestCoverageNoDataResponse } from './stories_constants';

Vue.use(VueApollo);

export default {
  component: TestCoverageSummary,
  title: 'ee/analytics/repository_analytics/components/test_coverage_summary',
};

const createStory = ({ mockApollo, response = groupTestCoverageResponse } = {}) => {
  const defaultApolloProvider = createMockApollo([
    [getGroupTestCoverage, () => Promise.resolve(response)],
  ]);

  return (args, { argTypes }) => ({
    components: { TestCoverageSummary },
    apolloProvider: mockApollo || defaultApolloProvider,
    provide: {
      groupFullPath: 'path/to/group',
      groupName: 'Group Awesome',
    },
    props: Object.keys(argTypes),
    template: '<test-coverage-summary />',
  });
};

export const Default = {
  render: createStory(),
};

export const Loading = {
  render: createStory({
    mockApollo: createMockApollo([[getGroupTestCoverage, () => new Promise(() => {})]]),
  }),
};

export const NoData = {
  render: createStory({ response: groupTestCoverageNoDataResponse }),
};
