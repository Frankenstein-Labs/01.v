import { mockDoraPerformersScoreResponseData } from './mock_data';

export const mockGraphqlDoraPerformanceScoreCountsResponse = ({
  mockDataResponse = mockDoraPerformersScoreResponseData,
  totalProjectsCount = 0,
  noDoraDataProjectsCount = 0,
} = {}) =>
  jest.fn().mockResolvedValue({
    data: {
      group: {
        id: 'fake-dora-performance-score-counts-request',
        doraPerformanceScoreCounts: {
          totalProjectsCount,
          noDoraDataProjectsCount,
          nodes: mockDataResponse,
        },
      },
    },
  });
