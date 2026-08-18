import Vue from 'vue';
import VueApollo from 'vue-apollo';
import createMockApollo from 'helpers/mock_apollo_helper';
import getProjectsTestCoverage from '../graphql/queries/get_projects_test_coverage.query.graphql';
import TestCoverageTable from './test_coverage_table.vue';
import {
  projectsTestCoverageResponse,
  projectsTestCoverageNoDataResponse,
} from './stories_constants';

Vue.use(VueApollo);

export default {
  component: TestCoverageTable,
  title: 'ee/analytics/repository_analytics/components/test_coverage_table',
};

const createStory = ({ mockApollo, response = projectsTestCoverageResponse } = {}) => {
  const defaultApolloProvider = createMockApollo([
    [getProjectsTestCoverage, () => Promise.resolve(response)],
  ]);

  return (args, { argTypes }) => ({
    components: { TestCoverageTable },
    apolloProvider: mockApollo || defaultApolloProvider,
    provide: {
      groupFullPath: 'path/to/group',
      groupName: 'Group Awesome',
    },
    props: Object.keys(argTypes),
    template: '<test-coverage-table />',
  });
};

export const Default = {
  render: createStory(),
};

export const Loading = {
  render: createStory({
    mockApollo: createMockApollo([[getProjectsTestCoverage, () => new Promise(() => {})]]),
  }),
};

export const NoData = {
  render: createStory({ response: projectsTestCoverageNoDataResponse }),
};
