import localRoadmapSettingsQuery from 'ee/roadmap/queries/local_roadmap_settings.query.graphql';
import { mockLocalRoadmapSettings } from 'ee_jest/roadmap/mock_data';

export const setLocalSettingsInCache = (apolloProvider, settings = {}) => {
  apolloProvider.clients.defaultClient.cache.writeQuery({
    query: localRoadmapSettingsQuery,
    data: {
      localRoadmapSettings: {
        __typename: 'LocalRoadmapSettings',
        ...mockLocalRoadmapSettings,
        ...settings,
      },
    },
  });
};

export const expectPayload = (payload) => [
  expect.any(Object),
  { input: payload },
  expect.any(Object),
  expect.any(Object),
];
