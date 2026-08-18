import mockCodeSuggestionsByLanguageData from 'test_fixtures/ee/graphql/analytics/dashboards/ai_impact/graphql/code_suggestions_acceptance_by_language.query.graphql.json';
import mockCodeSuggestionsByLanguageEmpty from 'test_fixtures/ee/graphql/analytics/dashboards/ai_impact/graphql/code_suggestions_acceptance_by_language.query.graphql.empty.json';
import mockCodeSuggestionsByLanguageVariants from 'test_fixtures/ee/graphql/analytics/dashboards/ai_impact/graphql/code_suggestions_acceptance_by_language.query.graphql.language_variants.json';
import mockCodeSuggestionsByLanguageWithEmptyLanguage from 'test_fixtures/ee/graphql/analytics/dashboards/ai_impact/graphql/code_suggestions_acceptance_by_language.query.graphql.with_empty_language.json';
import mockCodeSuggestionsByLanguageZeroAccepted from 'test_fixtures/ee/graphql/analytics/dashboards/ai_impact/graphql/code_suggestions_acceptance_by_language.query.graphql.zero_accepted.json';
import mockCodeSuggestionsByLanguageNullRate from 'test_fixtures/ee/graphql/analytics/dashboards/ai_impact/graphql/code_suggestions_acceptance_by_language.query.graphql.null_acceptance_rate.json';
import codeSuggestionsAcceptanceByLanguage from 'ee/analytics/analytics_dashboards/data_sources/code_suggestions_acceptance_by_language';
import { defaultClient } from 'ee/analytics/analytics_dashboards/graphql/client';
import {
  DATE_RANGE_OPTION_LAST_180_DAYS,
  DATE_RANGE_OPTION_LAST_90_DAYS,
} from 'ee/analytics/analytics_dashboards/components/filters/constants';

const INVALID_DATE_RANGE = 'invalid-range';

const defaultParams = {
  title: 'Code suggestions acceptance',
  namespace: 'test-namespace',
  query: { dateRange: DATE_RANGE_OPTION_LAST_90_DAYS },
};

describe('`Code suggestion acceptance by language` Data Source', () => {
  let res;

  const setVisualizationOverrides = jest.fn();

  const fetch = async (args) => {
    res = await codeSuggestionsAcceptanceByLanguage({
      setVisualizationOverrides,
      ...defaultParams,
      ...args,
    });
  };

  const mockQueryResponse = (response = mockCodeSuggestionsByLanguageData) =>
    jest.spyOn(defaultClient, 'query').mockResolvedValue(response);

  const expectQueryWithVariables = (variables) =>
    expect(defaultClient.query).toHaveBeenCalledWith(
      expect.objectContaining({
        variables: expect.objectContaining(variables),
      }),
    );

  afterEach(() => {
    jest.clearAllMocks();
  });

  describe('fetch', () => {
    describe('with data available', () => {
      beforeEach(() => {
        mockQueryResponse();

        return fetch();
      });

      it('makes a single request with the resolved date range', () => {
        expect(defaultClient.query).toHaveBeenCalledTimes(1);
        expectQueryWithVariables({
          fullPath: 'test-namespace',
          startDate: '2020-04-07',
          endDate: '2020-07-06',
        });
      });

      it('returns code suggestion acceptance metrics by language in ascending order', () => {
        expect(res).toEqual({
          'Suggestions accepted': [
            [1, 'Ruby'],
            [2, 'Python'],
          ],
          contextualData: {
            Ruby: { acceptanceRate: 0.5, shownCount: 2 },
            Python: { acceptanceRate: 1, shownCount: 2 },
          },
        });
      });

      it('calls `setVisualizationOverrides` with correct visualization title and chart options', () => {
        expect(setVisualizationOverrides).toHaveBeenCalledWith({
          visualizationOptionOverrides: expect.objectContaining({
            tooltip: {
              description:
                'Accepted GitLab Duo Code Suggestions by programming language. %{linkStart}Learn more%{linkEnd}.',
              descriptionLink:
                '/help/user/analytics/duo_and_sdlc_trends#gitlab-duo-code-suggestions-acceptance-by-language',
            },
            yAxis: {
              axisLabel: {
                formatter: expect.any(Function),
              },
            },
          }),
        });
      });
    });

    describe('with language variants that map to the same display name', () => {
      it('merges variants into a single entry and re-sorts by summed accepted count', async () => {
        mockQueryResponse(mockCodeSuggestionsByLanguageVariants);

        await fetch();

        expect(res).toEqual({
          'Suggestions accepted': [
            [2, 'Ruby'],
            [4, 'JavaScript'],
          ],
          contextualData: {
            Ruby: { acceptanceRate: 1, shownCount: 2 },
            JavaScript: { acceptanceRate: 1, shownCount: 4 },
          },
        });
      });
    });

    describe('with no data available', () => {
      it('returns an empty object when there are no nodes', async () => {
        mockQueryResponse(mockCodeSuggestionsByLanguageEmpty);

        await fetch();

        expect(defaultClient.query).toHaveBeenCalledTimes(1);
        expect(res).toEqual({});
      });

      it('returns an empty object when no language has accepted suggestions', async () => {
        mockQueryResponse(mockCodeSuggestionsByLanguageZeroAccepted);

        await fetch();

        expect(res).toEqual({});
      });
    });

    describe('with an empty language', () => {
      it('filters out nodes without a language', async () => {
        mockQueryResponse(mockCodeSuggestionsByLanguageWithEmptyLanguage);

        await fetch();

        expect(res).toEqual({
          'Suggestions accepted': [[1, 'Ruby']],
          contextualData: {
            Ruby: { acceptanceRate: 1, shownCount: 1 },
          },
        });
      });
    });

    describe('with a language that has no shown suggestions', () => {
      it('filters out nodes with a `null` acceptance rate', async () => {
        mockQueryResponse(mockCodeSuggestionsByLanguageNullRate);

        await fetch();

        expect(res).toEqual({
          'Suggestions accepted': [[1, 'Ruby']],
          contextualData: {
            Ruby: { acceptanceRate: 1, shownCount: 1 },
          },
        });
      });
    });

    describe('with unsupported date range', () => {
      it('falls back to fetching data for `DATE_RANGE_OPTION_LAST_30_DAYS`', async () => {
        mockQueryResponse();

        await fetch({
          query: { dateRange: INVALID_DATE_RANGE },
        });

        expectQueryWithVariables({
          fullPath: 'test-namespace',
          startDate: '2020-06-06',
          endDate: '2020-07-06',
        });
      });
    });

    describe('query overrides', () => {
      it('can override the date range', async () => {
        mockQueryResponse();

        await fetch({
          query: { dateRange: DATE_RANGE_OPTION_LAST_180_DAYS },
        });

        expectQueryWithVariables({
          fullPath: 'test-namespace',
          startDate: '2020-01-08',
          endDate: '2020-07-06',
        });
      });

      it('can override the namespace', async () => {
        mockQueryResponse();

        await fetch({
          query: { dateRange: DATE_RANGE_OPTION_LAST_90_DAYS, namespace: 'cool-namespace' },
        });

        expectQueryWithVariables({
          fullPath: 'cool-namespace',
          startDate: '2020-04-07',
          endDate: '2020-07-06',
        });
      });
    });
  });
});
