import { TYPENAME_GROUP, TYPENAME_PROJECT } from '~/graphql_shared/constants';

const mockIteration = {
  title: 'Iteration 1',
  __typename: 'Iteration',
};

const mockLabels = {
  count: 1,
  nodes: [
    {
      id: 'gid://gitlab/GroupLabel/25',
      color: '#5fa752',
      title: 'label',
      description: null,
      __typename: 'Label',
    },
  ],
  __typename: 'LabelConnection',
};

const createIssue = (values) => {
  return {
    state: values.state ?? 'closed',
    epic: {
      iid: 12345,
      __typename: 'Epic',
    },
    labels: {
      count: 0,
      nodes: [],
      __typename: 'LabelConnection',
    },
    milestone: {
      title: '11.1',
      __typename: 'Milestone',
    },
    iteration: null,
    weight: '3',
    dueDate: '2020-10-08',
    assignees: {
      count: 0,
      nodes: [],
      __typename: 'UserCoreConnection',
    },
    author: {
      name: 'Administrator',
      webUrl: 'link-to-author',
      avatarUrl: 'link-to-avatar',
      __typename: 'UserCore',
    },
    webUrl: `issues/${values.iid}`,
    iid: values.iid,
    ...values,
    __typename: 'Issue',
  };
};

export const mockIssuesApiResponse = [
  createIssue({ iid: 12345, title: 'Issue-1', createdAt: '2020-01-08' }),
  createIssue({
    iid: 23456,
    state: 'opened',
    title: 'Issue-2',
    createdAt: '2020-01-07',
    labels: mockLabels,
  }),
  createIssue({
    iid: 34567,
    state: 'opened',
    title: 'Issue-3',
    createdAt: '2020-01-6',
    iteration: mockIteration,
  }),
  createIssue({
    iid: 34567,
    state: 'locked',
    title: 'Issue-3',
    createdAt: '2020-01-6',
    iteration: mockIteration,
  }),
];

export const tableHeaders = [
  'Issue',
  'Age',
  'Status',
  'Milestone',
  'Iteration',
  'Weight',
  'Due date',
  'Assignees',
  'Created by',
];

export const getQueryIssuesAnalyticsResponse = {
  data: {
    group: {
      id: 'gid://gitlab/Group/22',
      issues: {
        count: 3,
        nodes: mockIssuesApiResponse,
        __typename: 'IssueConnection',
      },
      __typename: 'Group',
    },
  },
};

export const mockIssuesAnalyticsCountsStartDate = new Date('2022-11-01T00:00:00.000Z');
export const mockIssuesAnalyticsCountsEndDate = new Date('2023-11-20T00:00:00.000Z');

export const getMockIssuesAnalyticsCountsQuery = ({
  queryAlias,
  metricType,
  isProject = false,
} = {}) => `query get${queryAlias}($fullPath: ID!, $assigneeUsernames: [String!], $authorUsername: String, $milestoneTitle: String, $labelNames: [String!], $epicId: ID, $iterationId: ID, $myReactionEmoji: String, $weight: Int, $not: NegatedValueStreamAnalyticsIssuableFilterInput) {
  namespace: ${isProject ? 'project' : 'group'}(fullPath: $fullPath) {
    id
    ${queryAlias}: flowMetrics {
      query_2022_11: ${metricType}(
        from: "2022-11-01"
        to: "2022-12-01"
        assigneeUsernames: $assigneeUsernames
        authorUsername: $authorUsername
        milestoneTitle: $milestoneTitle
        labelNames: $labelNames
        epicId: $epicId
        iterationId: $iterationId
        myReactionEmoji: $myReactionEmoji
        weight: $weight
        not: $not
      ) {
        value
      }
      query_2022_12: ${metricType}(
        from: "2022-12-01"
        to: "2023-01-01"
        assigneeUsernames: $assigneeUsernames
        authorUsername: $authorUsername
        milestoneTitle: $milestoneTitle
        labelNames: $labelNames
        epicId: $epicId
        iterationId: $iterationId
        myReactionEmoji: $myReactionEmoji
        weight: $weight
        not: $not
      ) {
        value
      }
      query_2023_1: ${metricType}(
        from: "2023-01-01"
        to: "2023-02-01"
        assigneeUsernames: $assigneeUsernames
        authorUsername: $authorUsername
        milestoneTitle: $milestoneTitle
        labelNames: $labelNames
        epicId: $epicId
        iterationId: $iterationId
        myReactionEmoji: $myReactionEmoji
        weight: $weight
        not: $not
      ) {
        value
      }
      query_2023_2: ${metricType}(
        from: "2023-02-01"
        to: "2023-03-01"
        assigneeUsernames: $assigneeUsernames
        authorUsername: $authorUsername
        milestoneTitle: $milestoneTitle
        labelNames: $labelNames
        epicId: $epicId
        iterationId: $iterationId
        myReactionEmoji: $myReactionEmoji
        weight: $weight
        not: $not
      ) {
        value
      }
      query_2023_3: ${metricType}(
        from: "2023-03-01"
        to: "2023-04-01"
        assigneeUsernames: $assigneeUsernames
        authorUsername: $authorUsername
        milestoneTitle: $milestoneTitle
        labelNames: $labelNames
        epicId: $epicId
        iterationId: $iterationId
        myReactionEmoji: $myReactionEmoji
        weight: $weight
        not: $not
      ) {
        value
      }
      query_2023_4: ${metricType}(
        from: "2023-04-01"
        to: "2023-05-01"
        assigneeUsernames: $assigneeUsernames
        authorUsername: $authorUsername
        milestoneTitle: $milestoneTitle
        labelNames: $labelNames
        epicId: $epicId
        iterationId: $iterationId
        myReactionEmoji: $myReactionEmoji
        weight: $weight
        not: $not
      ) {
        value
      }
      query_2023_5: ${metricType}(
        from: "2023-05-01"
        to: "2023-06-01"
        assigneeUsernames: $assigneeUsernames
        authorUsername: $authorUsername
        milestoneTitle: $milestoneTitle
        labelNames: $labelNames
        epicId: $epicId
        iterationId: $iterationId
        myReactionEmoji: $myReactionEmoji
        weight: $weight
        not: $not
      ) {
        value
      }
      query_2023_6: ${metricType}(
        from: "2023-06-01"
        to: "2023-07-01"
        assigneeUsernames: $assigneeUsernames
        authorUsername: $authorUsername
        milestoneTitle: $milestoneTitle
        labelNames: $labelNames
        epicId: $epicId
        iterationId: $iterationId
        myReactionEmoji: $myReactionEmoji
        weight: $weight
        not: $not
      ) {
        value
      }
      query_2023_7: ${metricType}(
        from: "2023-07-01"
        to: "2023-08-01"
        assigneeUsernames: $assigneeUsernames
        authorUsername: $authorUsername
        milestoneTitle: $milestoneTitle
        labelNames: $labelNames
        epicId: $epicId
        iterationId: $iterationId
        myReactionEmoji: $myReactionEmoji
        weight: $weight
        not: $not
      ) {
        value
      }
      query_2023_8: ${metricType}(
        from: "2023-08-01"
        to: "2023-09-01"
        assigneeUsernames: $assigneeUsernames
        authorUsername: $authorUsername
        milestoneTitle: $milestoneTitle
        labelNames: $labelNames
        epicId: $epicId
        iterationId: $iterationId
        myReactionEmoji: $myReactionEmoji
        weight: $weight
        not: $not
      ) {
        value
      }
      query_2023_9: ${metricType}(
        from: "2023-09-01"
        to: "2023-10-01"
        assigneeUsernames: $assigneeUsernames
        authorUsername: $authorUsername
        milestoneTitle: $milestoneTitle
        labelNames: $labelNames
        epicId: $epicId
        iterationId: $iterationId
        myReactionEmoji: $myReactionEmoji
        weight: $weight
        not: $not
      ) {
        value
      }
      query_2023_10: ${metricType}(
        from: "2023-10-01"
        to: "2023-11-01"
        assigneeUsernames: $assigneeUsernames
        authorUsername: $authorUsername
        milestoneTitle: $milestoneTitle
        labelNames: $labelNames
        epicId: $epicId
        iterationId: $iterationId
        myReactionEmoji: $myReactionEmoji
        weight: $weight
        not: $not
      ) {
        value
      }
      query_2023_11: ${metricType}(
        from: "2023-11-01"
        to: "2023-11-20"
        assigneeUsernames: $assigneeUsernames
        authorUsername: $authorUsername
        milestoneTitle: $milestoneTitle
        labelNames: $labelNames
        epicId: $epicId
        iterationId: $iterationId
        myReactionEmoji: $myReactionEmoji
        weight: $weight
        not: $not
      ) {
        value
      }
    }
  }
}`;

export const getMockIssuesOpenedCountsResponse = ({ isProject = false, isEmpty = false } = {}) => ({
  id: 'fake-id',
  issuesOpenedCounts: {
    query_2022_11: {
      value: isEmpty ? 0 : 18,
      __typename: 'ValueStreamAnalyticsMetric',
    },
    query_2022_12: {
      value: isEmpty ? 0 : 38,
      __typename: 'ValueStreamAnalyticsMetric',
    },
    query_2023_1: {
      value: isEmpty ? 0 : 51,
      __typename: 'ValueStreamAnalyticsMetric',
    },
    query_2023_2: {
      value: isEmpty ? 0 : 39,
      __typename: 'ValueStreamAnalyticsMetric',
    },
    query_2023_3: {
      value: isEmpty ? 0 : 45,
      __typename: 'ValueStreamAnalyticsMetric',
    },
    query_2023_4: {
      value: isEmpty ? 0 : 40,
      __typename: 'ValueStreamAnalyticsMetric',
    },
    query_2023_5: {
      value: isEmpty ? 0 : 44,
      __typename: 'ValueStreamAnalyticsMetric',
    },
    query_2023_6: {
      value: isEmpty ? 0 : 44,
      __typename: 'ValueStreamAnalyticsMetric',
    },
    query_2023_7: {
      value: isEmpty ? 0 : 34,
      __typename: 'ValueStreamAnalyticsMetric',
    },
    query_2023_8: {
      value: isEmpty ? 0 : 48,
      __typename: 'ValueStreamAnalyticsMetric',
    },
    query_2023_9: {
      value: isEmpty ? 0 : 40,
      __typename: 'ValueStreamAnalyticsMetric',
    },
    query_2023_10: {
      value: isEmpty ? 0 : 39,
      __typename: 'ValueStreamAnalyticsMetric',
    },
    query_2023_11: {
      value: isEmpty ? 0 : 20,
      __typename: 'ValueStreamAnalyticsMetric',
    },
    __typename: isProject
      ? 'ProjectValueStreamAnalyticsFlowMetrics'
      : 'GroupValueStreamAnalyticsFlowMetrics',
  },
  __typename: isProject ? TYPENAME_PROJECT : TYPENAME_GROUP,
});

export const getMockIssuesClosedCountsResponse = ({ isProject = false, isEmpty = false } = {}) => ({
  id: 'fake-id',
  issuesClosedCounts: {
    query_2022_11: {
      value: isEmpty ? 0 : 0,
      __typename: 'ValueStreamAnalyticsMetric',
    },
    query_2022_12: {
      value: isEmpty ? 0 : 0,
      __typename: 'ValueStreamAnalyticsMetric',
    },
    query_2023_1: {
      value: isEmpty ? 0 : 1,
      __typename: 'ValueStreamAnalyticsMetric',
    },
    query_2023_2: {
      value: isEmpty ? 0 : 3,
      __typename: 'ValueStreamAnalyticsMetric',
    },
    query_2023_3: {
      value: isEmpty ? 0 : 4,
      __typename: 'ValueStreamAnalyticsMetric',
    },
    query_2023_4: {
      value: isEmpty ? 0 : 9,
      __typename: 'ValueStreamAnalyticsMetric',
    },
    query_2023_5: {
      value: isEmpty ? 0 : 13,
      __typename: 'ValueStreamAnalyticsMetric',
    },
    query_2023_6: {
      value: isEmpty ? 0 : 12,
      __typename: 'ValueStreamAnalyticsMetric',
    },
    query_2023_7: {
      value: isEmpty ? 0 : 14,
      __typename: 'ValueStreamAnalyticsMetric',
    },
    query_2023_8: {
      value: isEmpty ? 0 : 21,
      __typename: 'ValueStreamAnalyticsMetric',
    },
    query_2023_9: {
      value: isEmpty ? 0 : 24,
      __typename: 'ValueStreamAnalyticsMetric',
    },
    query_2023_10: {
      value: isEmpty ? 0 : 45,
      __typename: 'ValueStreamAnalyticsMetric',
    },
    query_2023_11: {
      value: isEmpty ? 0 : 60,
      __typename: 'ValueStreamAnalyticsMetric',
    },
    __typename: isProject
      ? 'ProjectValueStreamAnalyticsFlowMetrics'
      : 'GroupValueStreamAnalyticsFlowMetrics',
  },
  __typename: isProject ? TYPENAME_PROJECT : TYPENAME_GROUP,
});

export const getMockTotalIssuesAnalyticsCountsResponse = (isProject = false) => ({
  ...getMockIssuesOpenedCountsResponse({ isProject }),
  ...getMockIssuesClosedCountsResponse({ isProject }),
});

export const mockGroupIssuesAnalyticsCountsResponseData =
  getMockTotalIssuesAnalyticsCountsResponse();

export const mockProjectIssuesAnalyticsCountsResponseData =
  getMockTotalIssuesAnalyticsCountsResponse(true);

export const mockIssuesAnalyticsCountsChartData = [
  { name: 'Opened', data: [18, 38, 51, 39, 45, 40, 44, 44, 34, 48, 40, 39, 20] },
  { name: 'Closed', data: [0, 0, 1, 3, 4, 9, 13, 12, 14, 21, 24, 45, 60] },
];

export const mockOriginalFilters = {
  author_username: 'root',
  assignee_username: ['bob', 'smith'],
  label_name: ['Brest', 'DLT'],
  milestone_title: '16.4',
};

export const mockFilters = {
  authorUsername: 'root',
  assigneeUsernames: ['bob', 'smith'],
  labelName: ['Brest', 'DLT'],
  milestoneTitle: '16.4',
};
