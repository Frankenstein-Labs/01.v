export const usageBillingCacheConfig = {
  typePolicies: {
    Query: {
      fields: {
        subscriptionCreditsUsage: {
          merge: false,
        },
      },
    },
  },
};
