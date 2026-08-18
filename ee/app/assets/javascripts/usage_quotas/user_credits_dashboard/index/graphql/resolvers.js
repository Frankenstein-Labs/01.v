import { buildMockSelfCreditsUsage } from './mock_data';

// Local (client-side) resolver returning mocked data until the backend
// `selfCreditsUsage` field lands (gitlab-org/gitlab#605987).
export const resolvers = {
  Query: {
    selfCreditsUsage() {
      return buildMockSelfCreditsUsage();
    },
  },
};
