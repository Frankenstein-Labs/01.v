import mockFinishedPipelinesUsingDapEmptyResponseData from 'test_fixtures/ee/graphql/analytics/dashboards/ai_impact/graphql/finished_pipelines_using_dap.query.graphql.empty.json';
import mockFinishedPipelinesUsingDapGapsResponseData from 'test_fixtures/ee/graphql/analytics/dashboards/ai_impact/graphql/finished_pipelines_using_dap.query.graphql.gaps.json';
import mockFinishedPipelinesUsingDapResponseData from 'test_fixtures/ee/graphql/analytics/dashboards/ai_impact/graphql/finished_pipelines_using_dap.query.graphql.json';
import finishedPipelinesUsingDapOverTime from 'ee/analytics/analytics_dashboards/data_sources/finished_pipelines_using_dap_over_time';
import { defaultClient } from 'ee/analytics/analytics_dashboards/graphql/client';
import {
  DATE_RANGE_OPTION_LAST_180_DAYS,
  DATE_RANGE_OPTION_LAST_30_DAYS,
} from 'ee/analytics/analytics_dashboards/components/filters/constants';

describe('`Finished pipelines using DAP over time` data source', () => {
  let res;

  const namespace = 'test-namespace';
  const setVisualizationOverrides = jest.fn();

  const fetch = async (args = {}) => {
    res = await finishedPipelinesUsingDapOverTime({
      namespace,
      query: { dateRange: DATE_RANGE_OPTION_LAST_180_DAYS },
      setVisualizationOverrides,
      ...args,
    });
  };

  const mockResolvedQuery = (response = mockFinishedPipelinesUsingDapResponseData) =>
    jest.spyOn(defaultClient, 'query').mockResolvedValue(response);

  const expectQueryWithVariables = (variables) =>
    expect(defaultClient.query).toHaveBeenCalledWith(
      expect.objectContaining({
        variables: expect.objectContaining(variables),
      }),
    );

  describe('fetch', () => {
    describe('with data available', () => {
      beforeEach(() => {
        mockResolvedQuery();
        return fetch();
      });

      it('fetches data once with the correct variables', () => {
        expect(defaultClient.query).toHaveBeenCalledTimes(1);
        expectQueryWithVariables({
          fullPath: namespace,
          startDate: '2020-01-08',
          endDate: '2020-07-06',
        });
      });

      it('returns the correct chart series', () => {
        expect(res).toEqual([
          {
            name: 'With Agent Platform',
            data: [
              ['Jan 2020', 0],
              ['Feb 2020', 1],
              ['Mar 2020', 1],
              ['Apr 2020', 2],
              ['May 2020', 1],
              ['Jun 2020', 2],
              ['Jul 2020', 1],
            ],
          },
          {
            name: 'All Pipelines',
            data: [
              ['Jan 2020', 0],
              ['Feb 2020', 3],
              ['Mar 2020', 2],
              ['Apr 2020', 3],
              ['May 2020', 3],
              ['Jun 2020', 3],
              ['Jul 2020', 2],
            ],
          },
        ]);
      });

      it('sets the subtitle from the date range', () => {
        expect(setVisualizationOverrides).toHaveBeenCalledWith({
          visualizationOptionOverrides: expect.objectContaining({ subtitle: 'Last 180 days' }),
        });
      });

      it('calls `setVisualizationOverrides` with correct tooltip description and link', () => {
        expect(setVisualizationOverrides).toHaveBeenCalledWith({
          visualizationOptionOverrides: expect.objectContaining({
            tooltip: {
              description:
                'Tracks pipelines triggered by GitLab Duo Agent Platform compared to all pipelines. %{linkStart}Learn more%{linkEnd}.',
              descriptionLink:
                '/help/user/analytics/duo_and_sdlc_trends#pipelines-using-gitlab-duo-agent-platform',
            },
          }),
        });
      });
    });

    describe('with gaps in data', () => {
      beforeEach(() => {
        mockResolvedQuery(mockFinishedPipelinesUsingDapGapsResponseData);
        return fetch();
      });

      it('fills missing months with 0', () => {
        expect(res).toEqual([
          {
            name: 'With Agent Platform',
            data: [
              ['Jan 2020', 0],
              ['Feb 2020', 0],
              ['Mar 2020', 0],
              ['Apr 2020', 1],
              ['May 2020', 1],
              ['Jun 2020', 0],
              ['Jul 2020', 0],
            ],
          },
          {
            name: 'All Pipelines',
            data: [
              ['Jan 2020', 0],
              ['Feb 2020', 1],
              ['Mar 2020', 0],
              ['Apr 2020', 1],
              ['May 2020', 2],
              ['Jun 2020', 1],
              ['Jul 2020', 1],
            ],
          },
        ]);
      });
    });

    describe('with no data available', () => {
      beforeEach(() => {
        mockResolvedQuery(mockFinishedPipelinesUsingDapEmptyResponseData);
        return fetch();
      });

      it('returns an empty array', () => {
        expect(res).toEqual([]);
      });
    });

    describe('with a different date range', () => {
      beforeEach(() => {
        mockResolvedQuery();
        return fetch({ query: { dateRange: DATE_RANGE_OPTION_LAST_30_DAYS } });
      });

      it('uses the correct variables', () => {
        expectQueryWithVariables({
          fullPath: namespace,
          startDate: '2020-06-06',
          endDate: '2020-07-06',
        });
      });
    });
  });
});
