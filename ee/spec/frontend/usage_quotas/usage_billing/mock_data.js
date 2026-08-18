import { merge } from 'lodash-es';

const EMPTY_POOL = { totalCredits: 0, creditsUsed: 0 };
const USER_NULL_USAGE = {
  creditsUsed: null,
  monthlyCommitmentCreditsUsed: null,
  monthlyWaiverCreditsUsed: null,
  overageCreditsUsed: null,
  paidTierTrialCreditsUsed: null,
};

export const mockUsersUsageDataWithNoUsers = {
  data: {
    subscriptionUsage: {
      usersUsage: {
        // overall statistics
        totalUsers: 50,
        totalUsersUsingAllocation: 35,
        totalUsersUsingMonthlyCommitment: null, // or 0
        totalUsersBlocked: 10,
        avgCreditsPerUser: 150,
        dailyUsage: [
          { creditsUsed: 25, date: '2025-10-01' },
          { creditsUsed: 30, date: '2025-10-02' },
          { creditsUsed: 28, date: '2025-10-03' },
          { creditsUsed: 35, date: '2025-10-04' },
        ],

        // per-user details
        users: {
          nodes: [],
          pageInfo: {
            hasNextPage: false,
            hasPreviousPage: false,
            startCursor: null,
            endCursor: null,
          },
        },
      },
    },
  },
};

export const mockUsersUsageDataWithoutPool = merge({}, mockUsersUsageDataWithNoUsers, {
  data: {
    subscriptionUsage: {
      usersUsage: {
        users: {
          nodes: [
            {
              id: 'gid://gitlab/User/1',
              name: 'Alice Johnson',
              username: 'ajohnson',
              avatarUrl: 'https://www.gravatar.com/avatar/1?s=80&d=identicon',
              usage: {
                creditsUsed: 450,
                totalCredits: 500,
                monthlyCommitmentCreditsUsed: 0,
                monthlyWaiverCreditsUsed: 0,
                overageCreditsUsed: 0,
                paidTierTrialCreditsUsed: 0,
              },
              blockedStatus: { blocked: false },
            },
            {
              id: 'gid://gitlab/User/2',
              name: 'Bob Smith',
              username: 'bsmith',
              avatarUrl: 'https://www.gravatar.com/avatar/2?s=80&d=identicon',
              usage: {
                creditsUsed: 500,
                totalCredits: 500,
                monthlyCommitmentCreditsUsed: 0,
                monthlyWaiverCreditsUsed: 0,
                overageCreditsUsed: 67,
                paidTierTrialCreditsUsed: 0,
              },
              blockedStatus: { blocked: true },
            },
            {
              id: 'gid://gitlab/User/3',
              name: 'Carol Davis',
              username: 'cdavis',
              avatarUrl: 'https://www.gravatar.com/avatar/3?s=80&d=identicon',
              usage: {
                creditsUsed: 500,
                totalCredits: 500,
                monthlyCommitmentCreditsUsed: 0,
                monthlyWaiverCreditsUsed: 0,
                overageCreditsUsed: 89,
                paidTierTrialCreditsUsed: 0,
              },
              blockedStatus: { blocked: false },
            },
            {
              id: 'gid://gitlab/User/4',
              name: 'David Wilson',
              username: 'dwilson',
              avatarUrl: 'https://www.gravatar.com/avatar/4?s=80&d=identicon',
              usage: {
                creditsUsed: 320,
                totalCredits: 500,
                monthlyCommitmentCreditsUsed: 0,
                monthlyWaiverCreditsUsed: 0,
                overageCreditsUsed: 42,
                paidTierTrialCreditsUsed: 0,
              },
              blockedStatus: { blocked: false },
            },
            {
              id: 'gid://gitlab/User/5',
              name: 'Eva Martinez',
              username: 'emartinez',
              avatarUrl: 'https://www.gravatar.com/avatar/5?s=80&d=identicon',
              usage: {
                creditsUsed: 100,
                totalCredits: 500,
                monthlyCommitmentCreditsUsed: 0,
                monthlyWaiverCreditsUsed: 0,
                overageCreditsUsed: 0,
                paidTierTrialCreditsUsed: 0,
              },
              blockedStatus: { blocked: false },
            },
          ],
        },
      },
    },
  },
});

export const mockUsersUsageDataWithPool = merge({}, mockUsersUsageDataWithoutPool, {
  data: {
    subscriptionUsage: {
      usersUsage: {
        // overall statistics
        totalUsersUsingMonthlyCommitment: 15,
        totalUsersBlocked: 10,

        // per-user details
        users: {
          nodes: [
            {
              id: 'gid://gitlab/User/1',
              name: 'Alice Johnson',
              username: 'ajohnson',
              avatarUrl: 'https://www.gravatar.com/avatar/1?s=80&d=identicon',
              usage: {
                creditsUsed: 500,
                totalCredits: 500,
                monthlyCommitmentCreditsUsed: 70,
                monthlyWaiverCreditsUsed: 70,
                overageCreditsUsed: 50.333,
                paidTierTrialCreditsUsed: 0,
              },
              blockedStatus: { blocked: false },
            },
            {
              id: 'gid://gitlab/User/2',
              name: 'Bob Smith',
              username: 'bsmith',
              avatarUrl: 'https://www.gravatar.com/avatar/2?s=80&d=identicon',
              usage: {
                creditsUsed: 500,
                totalCredits: 500,
                monthlyCommitmentCreditsUsed: 0,
                monthlyWaiverCreditsUsed: 0,
                overageCreditsUsed: 0,
                paidTierTrialCreditsUsed: 0,
              },
              blockedStatus: { blocked: true },
            },
            {
              id: 'gid://gitlab/User/3',
              name: 'Carol Davis',
              username: 'cdavis',
              avatarUrl: 'https://www.gravatar.com/avatar/3?s=80&d=identicon',
              usage: {
                creditsUsed: 50,
                totalCredits: 500,
                monthlyCommitmentCreditsUsed: 0,
                monthlyWaiverCreditsUsed: 0,
                overageCreditsUsed: 0,
                paidTierTrialCreditsUsed: 0,
              },
              blockedStatus: { blocked: true },
            },
            {
              id: 'gid://gitlab/User/4',
              name: 'David Wilson',
              username: 'dwilson',
              avatarUrl: 'https://www.gravatar.com/avatar/4?s=80&d=identicon',
              usage: {
                creditsUsed: 2000,
                totalCredits: 2000,
                monthlyCommitmentCreditsUsed: 100,
                monthlyWaiverCreditsUsed: 0,
                overageCreditsUsed: 42.111,
                paidTierTrialCreditsUsed: 0,
              },
              blockedStatus: { blocked: false },
            },
            {
              id: 'gid://gitlab/User/5',
              name: 'Eva Martinez',
              username: 'emartinez',
              avatarUrl: 'https://www.gravatar.com/avatar/5?s=80&d=identicon',
              usage: {
                creditsUsed: 500,
                totalCredits: 500,
                monthlyCommitmentCreditsUsed: 75.888,
                monthlyWaiverCreditsUsed: 0,
                overageCreditsUsed: 15,
                paidTierTrialCreditsUsed: 0,
              },
              blockedStatus: { blocked: false },
            },
            {
              id: 'gid://gitlab/User/6',
              name: 'Frank Thompson',
              username: 'fthompson',
              avatarUrl: 'https://www.gravatar.com/avatar/6?s=80&d=identicon',
              usage: {
                creditsUsed: 480,
                totalCredits: 500,
                monthlyCommitmentCreditsUsed: 0,
                monthlyWaiverCreditsUsed: 0,
                overageCreditsUsed: 56,
                paidTierTrialCreditsUsed: 0,
              },
              blockedStatus: { blocked: true },
            },
            {
              id: 'gid://gitlab/User/7',
              name: 'Grace Lee',
              username: 'glee',
              avatarUrl: 'https://www.gravatar.com/avatar/7?s=80&d=identicon',
              usage: {
                creditsUsed: 500,
                totalCredits: 500,
                monthlyCommitmentCreditsUsed: 150,
                monthlyWaiverCreditsUsed: 0,
                overageCreditsUsed: 91,
                paidTierTrialCreditsUsed: 0,
              },
              blockedStatus: { blocked: false },
            },
            {
              id: 'gid://gitlab/User/8',
              name: 'Henry Brown',
              username: 'hbrown',
              avatarUrl: 'https://www.gravatar.com/avatar/8?s=80&d=identicon',
              usage: {
                creditsUsed: 500,
                totalCredits: 500,
                monthlyCommitmentCreditsUsed: 300,
                monthlyWaiverCreditsUsed: 0,
                overageCreditsUsed: 34,
                paidTierTrialCreditsUsed: 0,
              },
              blockedStatus: { blocked: false },
            },
          ],
        },
      },
    },
  },
});

export const mockUsersUsageDataWithOverage = merge({}, mockUsersUsageDataWithoutPool, {
  data: {
    subscriptionUsage: {
      usersUsage: {
        totalUsersUsingMonthlyCommitment: 15,

        users: {
          nodes: [
            {
              id: 'gid://gitlab/User/1',
              name: 'Alice Johnson',
              username: 'ajohnson',
              avatarUrl: 'https://www.gravatar.com/avatar/1?s=80&d=identicon',
              usage: {
                creditsUsed: 450,
                totalCredits: 500,
                monthlyCommitmentCreditsUsed: 0,
                monthlyWaiverCreditsUsed: 0,
                overageCreditsUsed: 23,
                paidTierTrialCreditsUsed: 0,
              },
              blockedStatus: { blocked: false },
            },
            {
              id: 'gid://gitlab/User/2',
              name: 'Bob Smith',
              username: 'bsmith',
              avatarUrl: 'https://www.gravatar.com/avatar/2?s=80&d=identicon',
              usage: {
                creditsUsed: 500,
                totalCredits: 500,
                monthlyCommitmentCreditsUsed: 125,
                monthlyWaiverCreditsUsed: 0,
                overageCreditsUsed: 67,
                paidTierTrialCreditsUsed: 0,
              },
              blockedStatus: { blocked: true },
            },
            {
              id: 'gid://gitlab/User/3',
              name: 'Carol Davis',
              username: 'cdavis',
              avatarUrl: 'https://www.gravatar.com/avatar/3?s=80&d=identicon',
              usage: {
                creditsUsed: 500,
                totalCredits: 500,
                monthlyCommitmentCreditsUsed: 200,
                monthlyWaiverCreditsUsed: 0,
                overageCreditsUsed: 89,
                paidTierTrialCreditsUsed: 0,
              },
              blockedStatus: { blocked: false },
            },
            {
              id: 'gid://gitlab/User/4',
              name: 'David Wilson',
              username: 'dwilson',
              avatarUrl: 'https://www.gravatar.com/avatar/4?s=80&d=identicon',
              usage: {
                creditsUsed: 320,
                totalCredits: 500,
                monthlyCommitmentCreditsUsed: 0,
                monthlyWaiverCreditsUsed: 0,
                overageCreditsUsed: 42,
                paidTierTrialCreditsUsed: 0,
              },
              blockedStatus: { blocked: false },
            },
            {
              id: 'gid://gitlab/User/5',
              name: 'Eva Martinez',
              username: 'emartinez',
              avatarUrl: 'https://www.gravatar.com/avatar/5?s=80&d=identicon',
              usage: {
                creditsUsed: 500,
                totalCredits: 500,
                monthlyCommitmentCreditsUsed: 75,
                monthlyWaiverCreditsUsed: 0,
                overageCreditsUsed: 15,
                paidTierTrialCreditsUsed: 0,
              },
              blockedStatus: { blocked: false },
            },
            {
              id: 'gid://gitlab/User/6',
              name: 'Frank Thompson',
              username: 'fthompson',
              avatarUrl: 'https://www.gravatar.com/avatar/6?s=80&d=identicon',
              usage: {
                creditsUsed: 480,
                totalCredits: 500,
                monthlyCommitmentCreditsUsed: 0,
                monthlyWaiverCreditsUsed: 0,
                overageCreditsUsed: 56,
                paidTierTrialCreditsUsed: 0,
              },
              blockedStatus: { blocked: false },
            },
            {
              id: 'gid://gitlab/User/7',
              name: 'Grace Lee',
              username: 'glee',
              avatarUrl: 'https://www.gravatar.com/avatar/7?s=80&d=identicon',
              usage: {
                creditsUsed: 500,
                totalCredits: 500,
                monthlyCommitmentCreditsUsed: 150,
                monthlyWaiverCreditsUsed: 0,
                overageCreditsUsed: 91,
                paidTierTrialCreditsUsed: 0,
              },
              blockedStatus: { blocked: false },
            },
            {
              id: 'gid://gitlab/User/8',
              name: 'Henry Brown',
              username: 'hbrown',
              avatarUrl: 'https://www.gravatar.com/avatar/8?s=80&d=identicon',
              usage: {
                creditsUsed: 500,
                totalCredits: 500,
                monthlyCommitmentCreditsUsed: 300,
                monthlyWaiverCreditsUsed: 0,
                overageCreditsUsed: 34,
                paidTierTrialCreditsUsed: 0,
              },
              blockedStatus: { blocked: false },
            },
          ],
        },
      },
    },
  },
});

export const mockUsersUsageDataWithZeroAllocation = merge({}, mockUsersUsageDataWithoutPool, {
  data: {
    subscriptionUsage: {
      usersUsage: {
        totalUsers: 5,
        totalUsersUsingAllocation: 2,
        totalUsersUsingMonthlyCommitment: 0,
        totalUsersBlocked: 1,

        users: {
          nodes: [
            {
              id: 'gid://gitlab/User/1',
              name: 'Alice Johnson',
              username: 'ajohnson',
              avatarUrl: 'https://www.gravatar.com/avatar/1?s=80&d=identicon',
              usage: {
                ...EMPTY_POOL,
                monthlyCommitmentCreditsUsed: 0,
                monthlyWaiverCreditsUsed: 12,
                overageCreditsUsed: 15,
                paidTierTrialCreditsUsed: 0,
              },
              blockedStatus: { blocked: false },
            },
            {
              id: 'gid://gitlab/User/2',
              name: 'Bob Smith',
              username: 'bsmith',
              avatarUrl: 'https://www.gravatar.com/avatar/2?s=80&d=identicon',
              usage: {
                ...EMPTY_POOL,
                monthlyCommitmentCreditsUsed: 0,
                monthlyWaiverCreditsUsed: 0,
                overageCreditsUsed: 0,
                paidTierTrialCreditsUsed: 0,
              },
              blockedStatus: { blocked: false },
            },
            {
              id: 'gid://gitlab/User/3',
              name: 'Carol Davis',
              username: 'cdavis',
              avatarUrl: 'https://www.gravatar.com/avatar/3?s=80&d=identicon',
              usage: {
                ...EMPTY_POOL,
                monthlyCommitmentCreditsUsed: 0,
                monthlyWaiverCreditsUsed: 5,
                overageCreditsUsed: 89,
                paidTierTrialCreditsUsed: 0,
              },
              blockedStatus: { blocked: true },
            },
            {
              id: 'gid://gitlab/User/4',
              name: 'David Wilson',
              username: 'dwilson',
              avatarUrl: 'https://www.gravatar.com/avatar/4?s=80&d=identicon',
              usage: {
                ...EMPTY_POOL,
                monthlyCommitmentCreditsUsed: 0,
                monthlyWaiverCreditsUsed: 0,
                overageCreditsUsed: 42,
                paidTierTrialCreditsUsed: 0,
              },
              blockedStatus: { blocked: false },
            },
            {
              id: 'gid://gitlab/User/5',
              name: 'Eva Martinez',
              username: 'emartinez',
              avatarUrl: 'https://www.gravatar.com/avatar/5?s=80&d=identicon',
              usage: {
                ...EMPTY_POOL,
                monthlyCommitmentCreditsUsed: 0,
                monthlyWaiverCreditsUsed: 0,
                overageCreditsUsed: 0,
                paidTierTrialCreditsUsed: 0,
              },
              blockedStatus: { blocked: false },
            },
          ],
        },
      },
    },
  },
});

export const mockUsersUsageDataWithNullUsage = merge({}, mockUsersUsageDataWithoutPool, {
  data: {
    subscriptionUsage: {
      usersUsage: {
        users: {
          nodes: [
            {
              id: 'gid://gitlab/User/6120463',
              name: 'Bryan Rothwell',
              username: 'brothwell',
              avatarUrl:
                'https://secure.gravatar.com/avatar/17c92ab7acbe41a4fd2e243828e5b711b3475526b188aa96c0f5039392d64ad8?s=80&d=identicon',
              usage: {
                totalCredits: 24,
                ...USER_NULL_USAGE,
                __typename: 'GitlabSubscriptionUsageUserUsage',
              },
              blockedStatus: null,
              __typename: 'GitlabSubscriptionUsageUser',
            },
            {
              id: 'gid://gitlab/User/5487870',
              name: 'Jorge Cook',
              username: 'jecook',
              avatarUrl:
                'https://secure.gravatar.com/avatar/4da03f30b1328ab1bf4ce9cfe88f447af5ad030bc52ef5825ab6bf06301bf39c?s=80&d=identicon',
              usage: {
                totalCredits: 24,
                ...USER_NULL_USAGE,
                __typename: 'GitlabSubscriptionUsageUserUsage',
              },
              blockedStatus: null,
              __typename: 'GitlabSubscriptionUsageUser',
            },
            {
              id: 'gid://gitlab/User/1943919',
              name: 'Kos Palchyk',
              username: 'kpalchyk',
              avatarUrl:
                'https://secure.gravatar.com/avatar/be1b9a030c184bc489faaa8fbb6679874660bbcec5df62bcd8dbd11cec02a4eb?s=80&d=identicon',
              usage: {
                totalCredits: null,
                ...USER_NULL_USAGE,
                __typename: 'GitlabSubscriptionUsageUserUsage',
              },
              blockedStatus: null,
              __typename: 'GitlabSubscriptionUsageUser',
            },
            {
              id: 'gid://gitlab/User/1862366',
              name: 'Sharmad Nachnolkar',
              username: 'snachnolkar',
              avatarUrl:
                'https://secure.gravatar.com/avatar/57e70f889048d230e2c7945babbe8bec8cbc90e20cf7b0388cd801a52f2243c6?s=80&d=identicon',
              usage: {
                totalCredits: 24,
                ...USER_NULL_USAGE,
                __typename: 'GitlabSubscriptionUsageUserUsage',
              },
              blockedStatus: null,
              __typename: 'GitlabSubscriptionUsageUser',
            },
            {
              id: 'gid://gitlab/User/1860447',
              name: 'Suraj Mahendra Tripathi',
              username: 'suraj_tripathy',
              avatarUrl:
                'https://secure.gravatar.com/avatar/97615be7789c22621ed96bc730c6819933fef80b1a7af3f95910c17f0e8615d3?s=80&d=identicon',
              usage: {
                totalCredits: 24,
                ...USER_NULL_USAGE,
                __typename: 'GitlabSubscriptionUsageUserUsage',
              },
              blockedStatus: null,
              __typename: 'GitlabSubscriptionUsageUser',
            },
            {
              id: 'gid://gitlab/User/1790300',
              name: 'Courtney Meddaugh',
              username: 'cmeddaugh',
              avatarUrl:
                'https://secure.gravatar.com/avatar/b4f1716310d4bb11d742604f8dda7ec30cebf0e7eacdbc241d42eb155c54fb03?s=80&d=identicon',
              usage: {
                totalCredits: 24,
                ...USER_NULL_USAGE,
                __typename: 'GitlabSubscriptionUsageUserUsage',
              },
              blockedStatus: null,
              __typename: 'GitlabSubscriptionUsageUser',
            },
            {
              id: 'gid://gitlab/User/1759714',
              name: 'Sheldon Led',
              username: 'sheldonled',
              avatarUrl:
                'https://secure.gravatar.com/avatar/d72fd8312645f293d485dfb87a50828c261e535357b6fe4bf4886332db33cd1a?s=80&d=identicon',
              usage: {
                totalCredits: 24,
                ...USER_NULL_USAGE,
                __typename: 'GitlabSubscriptionUsageUserUsage',
              },
              blockedStatus: null,
              __typename: 'GitlabSubscriptionUsageUser',
            },
            {
              id: 'gid://gitlab/User/1676960',
              name: 'Vijay Hawoldar',
              username: 'vhawoldar',
              avatarUrl:
                'https://secure.gravatar.com/avatar/e1fff3213210ed09a02bd837eb857a893683abb4cc5640a79929455c88a71487?s=80&d=identicon',
              usage: {
                creditsUsed: 0,
                totalCredits: 24,
                monthlyCommitmentCreditsUsed: 0,
                monthlyWaiverCreditsUsed: null,
                overageCreditsUsed: 0,
                paidTierTrialCreditsUsed: 0,
                __typename: 'GitlabSubscriptionUsageUserUsage',
              },
              blockedStatus: null,
              __typename: 'GitlabSubscriptionUsageUser',
            },
            {
              id: 'gid://gitlab/User/1675936',
              name: 'Ammar Alakkad',
              username: 'aalakkad',
              avatarUrl:
                'https://secure.gravatar.com/avatar/ef6157f79905c001112efda96ceb98fa1b0524a40ee9148bcf410793333a2614?s=80&d=identicon',
              usage: {
                totalCredits: 24,
                ...USER_NULL_USAGE,
                __typename: 'GitlabSubscriptionUsageUserUsage',
              },
              blockedStatus: null,
              __typename: 'GitlabSubscriptionUsageUser',
            },
            {
              id: 'gid://gitlab/User/1675825',
              name: 'Tyler Amos',
              username: 'tyleramos',
              avatarUrl:
                'https://secure.gravatar.com/avatar/6156236af081924c152da7bfc5b2ce1110628e2bb7a17ca2239038ec5a4f57bb?s=80&d=identicon',
              usage: {
                totalCredits: 24,
                ...USER_NULL_USAGE,
                __typename: 'GitlabSubscriptionUsageUserUsage',
              },
              blockedStatus: null,
              __typename: 'GitlabSubscriptionUsageUser',
            },
          ],
          pageInfo: {
            hasNextPage: false,
            hasPreviousPage: false,
            startCursor: 'eyJpZCI6IjYxMjA0NjMifQ',
            endCursor: 'eyJpZCI6IjE2NzU4MjUifQ',
            __typename: 'PageInfo',
          },
          __typename: 'GitlabSubscriptionUsageUserConnection',
        },
        __typename: 'GitlabSubscriptionUsageUsersUsage',
      },
      __typename: 'GitlabSubscriptionUsage',
    },
  },
});

export const mockUsageDataBase = {
  data: {
    subscriptionUsage: {
      enabled: true,
      isOutdatedClient: false,
      startDate: '2025-10-01',
      endDate: '2025-10-31',
      lastEventTransactionAt: null,
      canAcceptOverageTerms: true,
      subscriptionPortalUsageDashboardUrl:
        'https://customers.gitlab.com/subscriptions/A-S042/usage',
      purchaseCreditsPath: '/purchase-credits-path',
      paidTierTrial: {
        isActive: false,
        dailyUsage: [],
      },
      monthlyCommitment: {
        totalCredits: 0,
        creditsUsed: 0,
        dailyUsage: [],
      },
      monthlyWaiver: {
        totalCredits: null,
        creditsUsed: null,
        dailyUsage: [],
      },
      overage: {
        isAllowed: false,
        creditsUsed: 0,
        dailyUsage: [],
      },
      usersUsage: {
        dailyUsage: [],
      },
    },
  },
};

const mockUsageDataWithIncludedCredits = merge({}, mockUsageDataBase, {
  data: {
    subscriptionUsage: {
      lastEventTransactionAt: '2025-10-05T03:00:00Z',
      usersUsage: {
        dailyUsage: [
          { creditsUsed: 5, date: '2025-10-01' },
          { creditsUsed: 4, date: '2025-10-02' },
          { creditsUsed: 6, date: '2025-10-03' },
          { creditsUsed: 5.5, date: '2025-10-04' },
          { creditsUsed: 4.5, date: '2025-10-05' },
        ],
      },
    },
  },
});

export const usageDataWithCommitment = merge({}, mockUsageDataWithIncludedCredits, {
  data: {
    subscriptionUsage: {
      canAcceptOverageTerms: false,
      lastEventTransactionAt: '2025-10-11T03:00:00Z',
      monthlyCommitment: {
        creditsUsed: 50.333,
        totalCredits: 100,
        dailyUsage: [
          { creditsUsed: 5, date: '2025-10-06' },
          { creditsUsed: 12, date: '2025-10-07' },
          { creditsUsed: 18, date: '2025-10-10' },
          { creditsUsed: 15.333, date: '2025-10-11' },
        ],
      },
      overage: {
        isAllowed: true,
      },
    },
  },
});

const mockUsageDataWithCommitmentUsedUp = merge({}, mockUsageDataWithIncludedCredits, {
  data: {
    subscriptionUsage: {
      canAcceptOverageTerms: false,
      lastEventTransactionAt: '2025-10-11T03:00:00Z',
      monthlyCommitment: {
        creditsUsed: 50,
        totalCredits: 50,
        dailyUsage: [
          { creditsUsed: 8, date: '2025-10-01' },
          { creditsUsed: 12, date: '2025-10-02' },
          { creditsUsed: 10, date: '2025-10-03' },
          { creditsUsed: 15, date: '2025-10-04' },
          { creditsUsed: 5, date: '2025-10-05' },
        ],
      },
      overage: {
        isAllowed: true,
      },
    },
  },
});

export const usageDataWithCommitmentWithMonthlyWaiver = merge(
  {},
  mockUsageDataWithCommitmentUsedUp,
  {
    data: {
      subscriptionUsage: {
        lastEventTransactionAt: '2025-10-14T03:00:00Z',
        monthlyWaiver: {
          totalCredits: 100,
          creditsUsed: 75,
          dailyUsage: [
            { creditsUsed: 12.5, date: '2025-10-10' },
            { creditsUsed: 15.25, date: '2025-10-11' },
            { creditsUsed: 18.75, date: '2025-10-12' },
            { creditsUsed: 14.5, date: '2025-10-13' },
            { creditsUsed: 14, date: '2025-10-14' },
          ],
        },
      },
    },
  },
);

export const usageDataWithCommitmentWithOverage = merge({}, mockUsageDataWithCommitmentUsedUp, {
  data: {
    subscriptionUsage: {
      lastEventTransactionAt: '2025-10-14T03:00:00Z',
      overage: {
        isAllowed: true,
        creditsUsed: 50,
        dailyUsage: [
          { creditsUsed: 8.5, date: '2025-10-11' },
          { creditsUsed: 12.25, date: '2025-10-12' },
          { creditsUsed: 15.75, date: '2025-10-13' },
          { creditsUsed: 13.5, date: '2025-10-14' },
        ],
      },
    },
  },
});

export const usageDataNoCommitmentWithOverage = merge({}, mockUsageDataBase, {
  data: {
    subscriptionUsage: {
      canAcceptOverageTerms: false,
      lastEventTransactionAt: '2025-10-05T03:00:00Z',
      monthlyCommitment: null,
      overage: {
        isAllowed: true,
        creditsUsed: 50,
        dailyUsage: [
          { creditsUsed: 10.5, date: '2025-10-01' },
          { creditsUsed: 8.75, date: '2025-10-02' },
          { creditsUsed: 12.25, date: '2025-10-03' },
          { creditsUsed: 9.5, date: '2025-10-04' },
          { creditsUsed: 9, date: '2025-10-05' },
        ],
      },
    },
  },
});

export const usageDataNoCommitmentWithOverageWithOverageNotAllowed = merge(
  {},
  usageDataNoCommitmentWithOverage,
  {
    data: {
      subscriptionUsage: {
        canAcceptOverageTerms: true,
        overage: {
          isAllowed: false,
        },
      },
    },
  },
);

export const usageDataCommitmentWithMonthlyWaiverWithOverage = merge(
  {},
  mockUsageDataWithCommitmentUsedUp,
  {
    data: {
      subscriptionUsage: {
        lastEventTransactionAt: '2025-10-14T03:00:00Z',
        monthlyWaiver: {
          totalCredits: 100,
          creditsUsed: 100,
          dailyUsage: [
            { creditsUsed: 16.5, date: '2025-10-06' },
            { creditsUsed: 22.25, date: '2025-10-07' },
            { creditsUsed: 28.125, date: '2025-10-08' },
            { creditsUsed: 21.125, date: '2025-10-09' },
            { creditsUsed: 12, date: '2025-10-10' },
          ],
        },

        overage: {
          isAllowed: true,
          creditsUsed: 24,
          dailyUsage: [
            { creditsUsed: 4.5, date: '2025-10-11' },
            { creditsUsed: 6.25, date: '2025-10-12' },
            { creditsUsed: 7.75, date: '2025-10-13' },
            { creditsUsed: 5.5, date: '2025-10-14' },
          ],
        },
      },
    },
  },
);

export const usageDataWithOutdatedClient = merge({}, mockUsageDataBase, {
  data: {
    subscriptionUsage: {
      isOutdatedClient: true,
    },
  },
});

export const usageDataWithDisabledState = merge({}, mockUsageDataBase, {
  data: {
    subscriptionUsage: {
      enabled: false,
      isOutdatedClient: null,
      lastEventTransactionAt: null,
      startDate: null,
      endDate: null,
      purchaseCreditsPath: null,
    },
  },
});

export const usageDataWithoutPurchaseCreditsPath = merge({}, mockUsageDataBase, {
  data: {
    subscriptionUsage: {
      purchaseCreditsPath: null,
    },
  },
});

export const usageDataOnPaidTierTrial = merge({}, mockUsageDataWithIncludedCredits, {
  data: {
    subscriptionUsage: {
      lastEventTransactionAt: '2025-10-08T03:00:00Z',
      paidTierTrial: {
        isActive: true,
        dailyUsage: [
          { creditsUsed: 15, date: '2025-10-05' },
          { creditsUsed: 18, date: '2025-10-06' },
          { creditsUsed: 20, date: '2025-10-07' },
          { creditsUsed: 17, date: '2025-10-08' },
        ],
      },
    },
  },
});

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
                creditsUsed: 24,
                totalCredits: 24,
              },
            },
            {
              id: 'gid://gitlab/User/2',
              name: 'Bob Smith',
              username: 'bsmith',
              avatarUrl: 'https://www.gravatar.com/avatar/2?s=80&d=identicon',
              usage: {
                creditsUsed: 10,
                totalCredits: 24,
              },
            },
            {
              id: 'gid://gitlab/User/3',
              name: 'Carol Davis',
              username: 'cdavis',
              avatarUrl: 'https://www.gravatar.com/avatar/3?s=80&d=identicon',
              usage: {
                creditsUsed: 18,
                totalCredits: 24,
              },
            },
          ],
          pageInfo: {
            hasNextPage: false,
            hasPreviousPage: false,
            startCursor: null,
            endCursor: null,
          },
        },
      },
    },
  },
};

export const mockTrialUsersUsageDataWithZeroAllocation = {
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
                creditsUsed: 0,
                totalCredits: 0,
              },
            },
            {
              id: 'gid://gitlab/User/2',
              name: 'Bob Smith',
              username: 'bsmith',
              avatarUrl: 'https://www.gravatar.com/avatar/2?s=80&d=identicon',
              usage: {
                creditsUsed: 0,
                totalCredits: 0,
              },
            },
          ],
          pageInfo: {
            hasNextPage: false,
            hasPreviousPage: false,
            startCursor: null,
            endCursor: null,
          },
        },
      },
    },
  },
};
