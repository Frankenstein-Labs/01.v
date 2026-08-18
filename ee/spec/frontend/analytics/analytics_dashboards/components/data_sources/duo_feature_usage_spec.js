import fetch from 'ee/analytics/analytics_dashboards/data_sources/duo_feature_usage';
import { defaultClient } from 'ee/analytics/analytics_dashboards/graphql/client';

describe('Duo feature usage Data Source', () => {
  const namespace = 'namespace';
  let mockSetVisualizationOverrides;

  const mockResolvedQuery = () => {
    const spy = jest.spyOn(defaultClient, 'query');
    spy.mockResolvedValueOnce({
      data: {
        group: {
          aiMetrics: {
            codeSuggestions: {
              contributorsCount: 100,
              shownCount: 60,
            },
            duoChatContributorsCount: 200,
            chat: {
              requestDuoChatResponseEventCount: 100,
            },
            rootCauseAnalysisUsersCount: 20,
            troubleshoot: {
              troubleshootJobEventCount: 40,
            },
          },
        },
      },
    });
    spy.mockResolvedValueOnce({
      data: {
        group: {
          aiMetrics: {
            codeSuggestions: {
              contributorsCount: 200,
              shownCount: 120,
            },
            duoChatContributorsCount: 300,
            chat: {
              requestDuoChatResponseEventCount: 200,
            },
            rootCauseAnalysisUsersCount: 10,
            troubleshoot: {
              troubleshootJobEventCount: 20,
            },
          },
        },
      },
    });
  };

  const expectQueryWithVariables = (variables) =>
    expect(defaultClient.query).toHaveBeenCalledWith(
      expect.objectContaining({
        variables: expect.objectContaining(variables),
      }),
    );

  beforeEach(() => {
    mockSetVisualizationOverrides = jest.fn();
  });

  describe.each`
    dateRange    | subtitle           | startDate       | prevStartDate   | prevEndDate
    ${undefined} | ${'Last 30 days'}  | ${'2020-06-06'} | ${'2020-05-06'} | ${'2020-06-05'}
    ${'invalid'} | ${'Last 30 days'}  | ${'2020-06-06'} | ${'2020-05-06'} | ${'2020-06-05'}
    ${'30d'}     | ${'Last 30 days'}  | ${'2020-06-06'} | ${'2020-05-06'} | ${'2020-06-05'}
    ${'7d'}      | ${'Last 7 days'}   | ${'2020-06-29'} | ${'2020-06-21'} | ${'2020-06-28'}
    ${'60d'}     | ${'Last 60 days'}  | ${'2020-05-07'} | ${'2020-03-07'} | ${'2020-05-06'}
    ${'90d'}     | ${'Last 90 days'}  | ${'2020-04-07'} | ${'2020-01-07'} | ${'2020-04-06'}
    ${'180d'}    | ${'Last 180 days'} | ${'2020-01-08'} | ${'2019-07-11'} | ${'2020-01-07'}
    ${'365d'}    | ${'Last 365 days'} | ${'2019-07-07'} | ${'2018-07-06'} | ${'2019-07-06'}
  `(
    'when dateRange = $dateRange',
    ({ dateRange, subtitle, startDate, prevStartDate, prevEndDate }) => {
      beforeEach(() => {
        mockResolvedQuery();

        return fetch({
          namespace,
          query: { dateRange },
          setVisualizationOverrides: mockSetVisualizationOverrides,
        });
      });

      it(`shows the subtitle "${subtitle}"`, () => {
        expect(mockSetVisualizationOverrides).toHaveBeenCalledWith({
          visualizationOptionOverrides: expect.objectContaining({ subtitle }),
        });
      });

      it('sends a request for current and previous date ranges', () => {
        expect(defaultClient.query).toHaveBeenCalledTimes(2);
        expectQueryWithVariables({ startDate, endDate: '2020-07-06' });
        expectQueryWithVariables({ startDate: prevStartDate, endDate: prevEndDate });
      });
    },
  );

  it('shows the panel tooltip', async () => {
    mockResolvedQuery();
    await fetch({
      namespace,
      setVisualizationOverrides: mockSetVisualizationOverrides,
    });

    expect(mockSetVisualizationOverrides).toHaveBeenCalledWith({
      visualizationOptionOverrides: expect.objectContaining({
        tooltip: {
          description: "This table doesn't include GitLab Duo Agent Platform events.",
        },
      }),
    });
  });

  it('returns the data for the current and previous date range', async () => {
    mockResolvedQuery();

    const { nodes } = await fetch({ namespace });
    expect(nodes).toEqual([
      {
        featureName: 'Code Suggestions',
        eventCount: 60,
        userCount: 100,
        percentChange: {
          value: -0.5,
        },
      },
      {
        featureName: 'Chat (non-agentic)',
        eventCount: 100,
        userCount: 200,
        percentChange: {
          value: -0.5,
        },
      },
      {
        featureName: 'Root Cause Analysis',
        eventCount: 40,
        userCount: 20,
        percentChange: {
          value: 1,
        },
      },
    ]);
  });
});
