export const usageBillingCacheConfig = {
  typePolicies: {
    Query: {
      fields: {
        subscriptionUsage: {
          merge: false,
        },
      },
    },
  },
};
