import createMockApollo from 'helpers/mock_apollo_helper';
import { getQueryIssuesAnalyticsResponse } from 'ee_jest/issues_analytics/mock_data';
import { TEST_HOST } from 'helpers/test_constants';
import issueAnalyticsQuery from '../graphql/queries/issues_analytics.query.graphql';
import IssuesAnalyticsTable from './issues_analytics_table.vue';

export default {
  component: IssuesAnalyticsTable,
  title: 'ee/issues_analytics/components/issues_analytics_table',
};

const defaultQueryResolver = getQueryIssuesAnalyticsResponse;

const createStory = ({ mockApollo, requestHandler = defaultQueryResolver } = {}) => {
  const defaultApolloProvider = createMockApollo([
    [issueAnalyticsQuery, () => Promise.resolve(requestHandler)],
  ]);

  return (args, { argTypes }) => ({
    components: { IssuesAnalyticsTable },
    apolloProvider: mockApollo || defaultApolloProvider,
    provide: {
      fullPath: 'gitlab-org',
      type: 'group',
      issuesPageEndpoint: `${TEST_HOST}/issues/page`,
    },
    props: Object.keys(argTypes),
    template: '<issues-analytics-table v-bind="$props"/>',
  });
};

// NOTE: Nothing is rendered when there are no issues, so we do not need a "no data" state
export const Default = {
  render: createStory(),
  args: {
    startDate: new Date('2024-08-01'),
    endDate: new Date('2024-08-31'),
  },
};

export const Loading = {
  render: createStory({
    mockApollo: createMockApollo([[issueAnalyticsQuery, () => new Promise(() => {})]]),
  }),
  args: Default.args,
};
