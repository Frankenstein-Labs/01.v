import mockAiMetricsResponse from 'test_fixtures/ee/graphql/analytics/dashboards/ai_impact/graphql/ai_metrics.query.graphql.json';
import mockAiMetricsResponseColumn2 from 'test_fixtures/ee/graphql/analytics/dashboards/ai_impact/graphql/ai_metrics.query.graphql.column_2.json';
import mockAiMetricsResponseColumn3 from 'test_fixtures/ee/graphql/analytics/dashboards/ai_impact/graphql/ai_metrics.query.graphql.column_3.json';
import mockAiMetricsResponseColumn4 from 'test_fixtures/ee/graphql/analytics/dashboards/ai_impact/graphql/ai_metrics.query.graphql.column_4.json';
import mockAiMetricsNullResponseData from 'test_fixtures/ee/graphql/analytics/dashboards/ai_impact/graphql/ai_metrics.query.graphql.null_values.json';
import mockAiMetricsResponseEmptyCodeSuggestionDimensions from 'test_fixtures/ee/graphql/analytics/dashboards/ai_impact/graphql/ai_metrics.query.graphql.empty_code_suggestion_dimensions.json';
import { defaultClient } from 'ee/analytics/analytics_dashboards/graphql/client';
import {
  extractGraphqlAiData,
  fetchCodeSuggestionsMetricsByDimension,
} from 'ee/analytics/dashboards/ai_impact/api';
import { LANGUAGE_DIMENSION_KEY } from '~/analytics/shared/constants';

describe('AI impact dashboard api', () => {
  describe('extractGraphqlAiData', () => {
    it.each([
      ['code_suggestions_acceptance_rate', { codeSuggestions: { shownCount: 4 } }],
      ['code_suggestions_acceptance_rate', { codeSuggestions: { acceptedCount: 3 } }],
      [
        'code_suggestions_acceptance_rate',
        { codeSuggestions: { acceptedCount: 3, shownCount: 4 } },
      ],
      [
        'code_suggestions_acceptance_rate',
        { codeSuggestions: { acceptedCount: 0, shownCount: 20 } },
      ],
      ['code_suggestions_users_count', {}],
      ['code_suggestions_users_count', { codeSuggestions: { contributorsCount: 5 } }],
      ['code_suggestions_users_count', { codeSuggestions: { contributorsCount: 0 } }],
      ['duo_chat_users_count', {}],
      ['duo_chat_users_count', { duoChatContributorsCount: 4 }],
      ['duo_chat_users_count', { duoChatContributorsCount: 0 }],
      ['duo_rca_users_count', {}],
      ['duo_rca_users_count', { rootCauseAnalysisUsersCount: 10 }],
      ['duo_rca_users_count', { rootCauseAnalysisUsersCount: 0 }],
      ['duo_review_requests_count', {}],
      [
        'duo_review_requests_count',
        { codeReview: { requestReviewDuoCodeReviewOnMrByAuthorEventCount: 10 } },
      ],
      [
        'duo_review_requests_count',
        { codeReview: { requestReviewDuoCodeReviewOnMrByNonAuthorEventCount: 5 } },
      ],
      [
        'duo_review_requests_count',
        {
          codeReview: {
            requestReviewDuoCodeReviewOnMrByAuthorEventCount: 0,
            requestReviewDuoCodeReviewOnMrByNonAuthorEventCount: 0,
          },
        },
      ],
      [
        'duo_review_requests_count',
        {
          codeReview: {
            requestReviewDuoCodeReviewOnMrByAuthorEventCount: 5,
            requestReviewDuoCodeReviewOnMrByNonAuthorEventCount: 10,
          },
        },
      ],
      ['duo_review_comment_count', {}],
      [
        'duo_review_comment_count',
        { codeReview: { postCommentDuoCodeReviewOnDiffEventCount: 25 } },
      ],
      ['duo_review_comment_count', { codeReview: { postCommentDuoCodeReviewOnDiffEventCount: 0 } }],
      ['duo_agent_platform_flows', {}],
      ['duo_agent_platform_flows', { agentPlatformFlows: { createdSessionEventCount: 100 } }],
      ['duo_agent_platform_flows', { agentPlatformFlows: { createdSessionEventCount: 0 } }],
      ['duo_agent_platform_chats', {}],
      ['duo_agent_platform_chats', { agentPlatformChats: { createdSessionEventCount: 70 } }],
      ['duo_agent_platform_chats', { agentPlatformChats: { createdSessionEventCount: 0 } }],
    ])('returns %s given %o', (identifier, data) => {
      expect(extractGraphqlAiData(data)[identifier]).toMatchSnapshot();
    });
  });

  describe('fetchCodeSuggestionsMetricsByDimension', () => {
    const mockVariables = {
      fullPath: 'test-namespace',
      startDate: '2024-01-01',
      endDate: '2024-01-31',
    };

    const mockResolvedAiMetricsQuery = (response = mockAiMetricsResponse) =>
      jest.spyOn(defaultClient, 'query').mockResolvedValueOnce(response);

    const expectQueryWithVariables = (variables) =>
      expect(defaultClient.query).toHaveBeenCalledWith(
        expect.objectContaining({
          variables: expect.objectContaining(variables),
        }),
      );

    it('fetches metrics for each dimension item', async () => {
      mockResolvedAiMetricsQuery()
        .mockResolvedValueOnce(mockAiMetricsResponseColumn2)
        .mockResolvedValueOnce(mockAiMetricsResponseColumn3)
        .mockResolvedValueOnce(mockAiMetricsResponseColumn4);

      const { successful, failed } = await fetchCodeSuggestionsMetricsByDimension(
        mockVariables,
        LANGUAGE_DIMENSION_KEY,
      );

      expect(defaultClient.query).toHaveBeenCalledTimes(4);
      expectQueryWithVariables(mockVariables);
      expectQueryWithVariables({ ...mockVariables, languages: 'js' });
      expectQueryWithVariables({ ...mockVariables, languages: 'ruby' });
      expectQueryWithVariables({ ...mockVariables, languages: 'go' });

      expect(successful).toEqual([
        mockAiMetricsResponseColumn2,
        mockAiMetricsResponseColumn3,
        mockAiMetricsResponseColumn4,
      ]);
      expect(failed).toHaveLength(0);
    });

    it('only fetches metrics for supported dimension items', async () => {
      mockResolvedAiMetricsQuery(mockAiMetricsResponseEmptyCodeSuggestionDimensions);

      await fetchCodeSuggestionsMetricsByDimension(mockVariables, LANGUAGE_DIMENSION_KEY);

      expect(defaultClient.query).toHaveBeenCalledTimes(3);
    });

    it('separates successful and failed queries', async () => {
      mockResolvedAiMetricsQuery()
        .mockResolvedValueOnce(mockAiMetricsResponseColumn2)
        .mockRejectedValueOnce({})
        .mockRejectedValueOnce({});

      const { successful, failed } = await fetchCodeSuggestionsMetricsByDimension(
        mockVariables,
        LANGUAGE_DIMENSION_KEY,
      );

      expect(successful).toEqual([mockAiMetricsResponseColumn2]);
      expect(failed).toEqual(['ruby', 'go']);
    });

    it('returns empty results when there are no dimension items to fetch', async () => {
      mockResolvedAiMetricsQuery(mockAiMetricsNullResponseData);

      const { successful, failed } = await fetchCodeSuggestionsMetricsByDimension(
        mockVariables,
        LANGUAGE_DIMENSION_KEY,
      );

      expect(defaultClient.query).toHaveBeenCalledTimes(1);
      expect(successful).toHaveLength(0);
      expect(failed).toHaveLength(0);
    });

    it('throws error for invalid dimension key', async () => {
      await expect(
        fetchCodeSuggestionsMetricsByDimension(mockVariables, 'invalidKey'),
      ).rejects.toThrow('Invalid dimension key: invalidKey. Must be one of: ideNames, languages');
    });
  });
});
