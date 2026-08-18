import mockCodeSuggestionsByIdeData from 'test_fixtures/ee/graphql/analytics/dashboards/ai_impact/graphql/code_suggestions_acceptance_by_ide.query.graphql.json';
import mockCodeSuggestionsByIdeEmpty from 'test_fixtures/ee/graphql/analytics/dashboards/ai_impact/graphql/code_suggestions_acceptance_by_ide.query.graphql.empty.json';
import mockCodeSuggestionsByIdeWithUnnamedIde from 'test_fixtures/ee/graphql/analytics/dashboards/ai_impact/graphql/code_suggestions_acceptance_by_ide.query.graphql.with_empty_ide.json';
import mockCodeSuggestionsByIdeZeroAccepted from 'test_fixtures/ee/graphql/analytics/dashboards/ai_impact/graphql/code_suggestions_acceptance_by_ide.query.graphql.zero_accepted.json';
import mockCodeSuggestionsByIdeNullRate from 'test_fixtures/ee/graphql/analytics/dashboards/ai_impact/graphql/code_suggestions_acceptance_by_ide.query.graphql.null_acceptance_rate.json';
import codeSuggestionsAcceptanceRateByIde from 'ee/analytics/analytics_dashboards/data_sources/code_suggestions_acceptance_by_ide';
import { defaultClient } from 'ee/analytics/analytics_dashboards/graphql/client';
import {
  DATE_RANGE_OPTION_LAST_180_DAYS,
  DATE_RANGE_OPTION_LAST_90_DAYS,
} from 'ee/analytics/analytics_dashboards/components/filters/constants';

const INVALID_DATE_RANGE = 'invalid-range';

const defaultParams = {
  title: 'Code suggestions acceptance by IDE',
  namespace: 'test-namespace',
  query: { dateRange: DATE_RANGE_OPTION_LAST_90_DAYS },
};

describe('`Code suggestion acceptance rate by IDE` Data Source', () => {
  let res;

  const setVisualizationOverrides = jest.fn();

  const fetch = async (args) => {
    res = await codeSuggestionsAcceptanceRateByIde({
      setVisualizationOverrides,
      ...defaultParams,
      ...args,
    });
  };

  const mockQueryResponse = (response = mockCodeSuggestionsByIdeData) =>
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

      it('returns code suggestion acceptance metrics by IDE in ascending order', () => {
        expect(res).toEqual({
          'Suggestions accepted': [
            [0, 'PyCharm'],
            [3, 'RubyMine'],
          ],
          contextualData: {
            PyCharm: { acceptanceRate: 0, shownCount: 2 },
            RubyMine: { acceptanceRate: 0.75, shownCount: 4 },
          },
        });
      });

      it('calls `setVisualizationOverrides` with correct visualization title and chart options', () => {
        expect(setVisualizationOverrides).toHaveBeenCalledWith({
          visualizationOptionOverrides: expect.objectContaining({
            tooltip: {
              description:
                'Shows accepted GitLab Duo Code Suggestions by IDE. %{linkStart}Learn more%{linkEnd}.',
              descriptionLink:
                '/help/user/analytics/duo_and_sdlc_trends#gitlab-duo-code-suggestions-acceptance-by-ide',
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

    describe('with no data available', () => {
      it('returns an empty object when there are no nodes', async () => {
        mockQueryResponse(mockCodeSuggestionsByIdeEmpty);

        await fetch();

        expect(defaultClient.query).toHaveBeenCalledTimes(1);
        expect(res).toEqual({});
      });

      it('returns an empty object when no IDE has accepted suggestions', async () => {
        mockQueryResponse(mockCodeSuggestionsByIdeZeroAccepted);

        await fetch();

        expect(res).toEqual({});
      });
    });

    describe('with an unnamed IDE', () => {
      it('filters out nodes without an IDE name', async () => {
        mockQueryResponse(mockCodeSuggestionsByIdeWithUnnamedIde);

        await fetch();

        expect(res).toEqual({
          'Suggestions accepted': [[1, 'VS Code']],
          contextualData: {
            'VS Code': { acceptanceRate: 1, shownCount: 1 },
          },
        });
      });
    });

    describe('with an IDE that has no shown suggestions', () => {
      it('filters out nodes with a `null` acceptance rate', async () => {
        mockQueryResponse(mockCodeSuggestionsByIdeNullRate);

        await fetch();

        expect(res).toEqual({
          'Suggestions accepted': [[1, 'VS Code']],
          contextualData: {
            'VS Code': { acceptanceRate: 1, shownCount: 1 },
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
