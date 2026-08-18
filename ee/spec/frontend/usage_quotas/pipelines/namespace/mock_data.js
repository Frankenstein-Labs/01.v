import { TEST_HOST } from 'helpers/test_constants';

export const defaultProvide = Object.freeze({
  namespaceId: 12345,
  userNamespace: false,
  pageSize: '20',
  ciMinutesAnyProjectEnabled: true,
  ciMinutesDisplayMinutesAvailableData: true,
  ciMinutesLastResetDate: '2022-08-01',
  ciMinutesMonthlyMinutesLimit: '100',
  ciMinutesMonthlyMinutesUsed: 20,
  ciMinutesMonthlyMinutesUsedPercentage: 20,
  ciMinutesPurchasedMinutesLimit: '100',
  ciMinutesPurchasedMinutesUsed: 20,
  ciMinutesPurchasedMinutesUsedPercentage: 20,
  namespaceActualPlanName: 'MyGroup',
  buyAdditionalMinutesPath: `${TEST_HOST}/-/subscriptions/buy_minutes?selected_group=12345`,
  buyAdditionalMinutesTarget: '_self',
});

export const pageInfo = {
  __typename: 'PageInfo',
  hasNextPage: false,
  hasPreviousPage: false,
  startCursor: 'eyJpZCI6IjYifQ',
  endCursor: 'eyJpZCI6IjYifQ',
};

export const mockGetNamespaceCiMinutesUsage = {
  data: {
    ciMinutesUsage: {
      nodes: [
        {
          month: 'Jan',
          monthIso8601: '2021-01-01',
          minutes: 5,
          sharedRunnersDuration: 60,
        },
        {
          month: 'June',
          monthIso8601: '2022-06-01',
          minutes: 0,
          sharedRunnersDuration: 0,
        },
        {
          month: 'July',
          monthIso8601: '2022-07-01',
          minutes: 5,
          sharedRunnersDuration: 60,
        },
        {
          month: 'August',
          monthIso8601: '2022-08-01',
          minutes: 7,
          sharedRunnersDuration: 80,
        },
      ],
    },
  },
};

export const mockGetProjectsCiMinutesUsage = {
  data: {
    ciMinutesProjectMonthlyUsage: {
      nodes: [
        {
          minutes: 5,
          sharedRunnersDuration: 80,
          project: {
            id: 'gid://gitlab/Project/7',
            name: 'devcafe-mx',
            nameWithNamespace: 'Group / devcafe-mx',
            avatarUrl: null,
            webUrl: 'http://gdk.test:3000/group/devcafe-mx',
          },
        },
      ],
      pageInfo,
    },
  },
};

export const emptyMockGetCiMinutesUsageNamespaceProjects = {
  data: {
    ciMinutesProjectMonthlyUsage: {
      nodes: [],
      pageInfo,
    },
  },
};

export const defaultProjectListProps = {
  projects: mockGetProjectsCiMinutesUsage.data.ciMinutesProjectMonthlyUsage.nodes,
  pageInfo,
};
