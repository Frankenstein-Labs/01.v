/**
 * @file Mock data for free tier trial queries
 *
 * Based on:
 * - ee/app/assets/javascripts/usage_quotas/usage_billing/graphql/get_trial_usage.query.graphql
 * - ee/app/assets/javascripts/usage_quotas/usage_billing/graphql/get_trial_users_usage.query.graphql
 */

export const mockTrialUsageDataWithActiveTrial = {
  data: {
    trialUsage: {
      activeTrial: {
        startDate: '2025-10-15',
        endDate: '2025-11-15',
      },
      usersUsage: {
        creditsUsed: 35,
        totalUsersUsingCredits: 4,
      },
    },
  },
};

export const mockTrialUsersUsageData = {
  data: {
    trialUsage: {
      usersUsage: {
        users: {
          nodes: [
            {
              id: 'gid://gitlab/User/1',
              name: 'Alice Johnson',
              username: 'ajohnson',
              avatarUrl: 'https://www.gravatar.com/avatar/1?s=80&d=identicon',
              usage: {
                totalCredits: 24,
                creditsUsed: 24,
              },
            },
            {
              id: 'gid://gitlab/User/2',
              name: 'Bob Smith',
              username: 'bsmith',
              avatarUrl: 'https://www.gravatar.com/avatar/2?s=80&d=identicon',
              usage: {
                totalCredits: 24,
                creditsUsed: 5,
              },
            },
            {
              id: 'gid://gitlab/User/3',
              name: 'Carol Davis',
              username: 'cdavis',
              avatarUrl: 'https://www.gravatar.com/avatar/3?s=80&d=identicon',
              usage: {
                totalCredits: 24,
                creditsUsed: 3,
              },
            },
            {
              id: 'gid://gitlab/User/4',
              name: 'David Wilson',
              username: 'dwilson',
              avatarUrl: 'https://www.gravatar.com/avatar/4?s=80&d=identicon',
              usage: {
                totalCredits: 24,
                creditsUsed: 3,
              },
            },
          ],
          pageInfo: {
            hasNextPage: false,
            hasPreviousPage: false,
            startCursor: 'eyJpZCI6IjEifQ',
            endCursor: 'eyJpZCI6IjQifQ',
          },
        },
      },
    },
  },
};
