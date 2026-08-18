export const mockGraphqlIssuesAnalyticsCountsResponse = ({ mockDataResponse } = {}) =>
  jest.fn().mockResolvedValue({
    data: {
      namespace: mockDataResponse,
    },
  });
