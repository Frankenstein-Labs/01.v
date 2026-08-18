export const userCreditsCacheConfig = {
  typePolicies: {
    Query: {
      fields: {
        selfCreditsUsage: {
          merge: false,
        },
      },
    },
  },
};
