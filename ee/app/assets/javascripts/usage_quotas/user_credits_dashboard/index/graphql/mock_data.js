import { s__ } from '~/locale';

// Mocked response for the client-side `selfCreditsUsage` resolver. Replaced by
// the backend field in gitlab-org/gitlab#605987.

export const buildMockSelfCreditsUsage = () => ({
  __typename: 'GitlabSubscriptionSelfCreditsUsage',
  enabled: true,
  isOutdatedClient: false,
  startDate: '2026-07-01',
  endDate: '2026-07-14',
  creditsUsed: 19.1,
  dailyAverage: 1.4,
  dailyUsage: [
    { __typename: 'GitlabSubscriptionUsageDailyUsage', date: '2026-07-01', creditsUsed: 1.2 },
    { __typename: 'GitlabSubscriptionUsageDailyUsage', date: '2026-07-02', creditsUsed: 0.8 },
    { __typename: 'GitlabSubscriptionUsageDailyUsage', date: '2026-07-03', creditsUsed: 2.1 },
    { __typename: 'GitlabSubscriptionUsageDailyUsage', date: '2026-07-04', creditsUsed: 1.5 },
    { __typename: 'GitlabSubscriptionUsageDailyUsage', date: '2026-07-05', creditsUsed: 0.3 },
    { __typename: 'GitlabSubscriptionUsageDailyUsage', date: '2026-07-06', creditsUsed: 1.9 },
    { __typename: 'GitlabSubscriptionUsageDailyUsage', date: '2026-07-07', creditsUsed: 2.4 },
    { __typename: 'GitlabSubscriptionUsageDailyUsage', date: '2026-07-08', creditsUsed: 0.6 },
    { __typename: 'GitlabSubscriptionUsageDailyUsage', date: '2026-07-09', creditsUsed: 1.1 },
    { __typename: 'GitlabSubscriptionUsageDailyUsage', date: '2026-07-10', creditsUsed: 3.0 },
    { __typename: 'GitlabSubscriptionUsageDailyUsage', date: '2026-07-11', creditsUsed: 0.9 },
    { __typename: 'GitlabSubscriptionUsageDailyUsage', date: '2026-07-12', creditsUsed: 1.7 },
    { __typename: 'GitlabSubscriptionUsageDailyUsage', date: '2026-07-13', creditsUsed: 2.2 },
    { __typename: 'GitlabSubscriptionUsageDailyUsage', date: '2026-07-14', creditsUsed: 0.4 },
  ],
  products: [
    {
      __typename: 'GitlabSubscriptionUsageProduct',
      id: 'duo_agent_platform',
      title: s__('UsageBilling|GitLab Duo Agent Platform'),
      flowTypes: [
        {
          __typename: 'GitlabSubscriptionUsageProductFlowType',
          id: 'chat',
          title: s__('UsageBilling|Chat'),
        },
        {
          __typename: 'GitlabSubscriptionUsageProductFlowType',
          id: 'code_suggestions',
          title: s__('UsageBilling|Code Suggestions'),
        },
      ],
    },
  ],
  usedFlowTypes: [
    {
      __typename: 'GitlabSubscriptionUsageFlowTypeInfo',
      id: 'chat',
      title: s__('UsageBilling|Chat'),
    },
  ],
  blockedStatus: {
    __typename: 'GitlabSubscriptionUsageBlockedStatus',
    blocked: false,
    capType: null,
  },
});
