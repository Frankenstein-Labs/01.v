import doraMetricsByProject, {
  filterProjects,
} from 'ee/analytics/analytics_dashboards/data_sources/dora_metrics_by_project';
import {
  mockDataSourceResponses,
  mockProjectsDoraMetrics,
} from 'ee_jest/analytics/dashboards/dora_projects_comparison/mock_data';
import { defaultClient } from 'ee/analytics/analytics_dashboards/graphql/client';

describe('Dora Metrics by project Data Source', () => {
  const setAlerts = jest.fn();
  const setVisualizationOverrides = jest.fn();

  let res;

  const fetch = async (args) => {
    res = await doraMetricsByProject({
      namespace: 'cool namespace',
      isProject: false,
      setAlerts,
      setVisualizationOverrides,
      ...args,
    });
  };

  describe('filterProjects', () => {
    const mockUnfilteredProjectsDoraMetrics = [
      ...mockProjectsDoraMetrics,
      {
        name: 'No data',
        avatarUrl: 'http://gdk.test:3000/nodata',
        webUrl: 'http://gdk.test:3000/flightjs/nodata',
        deployment_frequency: null,
        change_failure_rate: null,
        lead_time_for_changes: null,
        time_to_restore_service: null,
        trends: {
          deployment_frequency: 0,
          lead_time_for_changes: 0,
          time_to_restore_service: 0,
          change_failure_rate: 0,
        },
      },
    ];

    it('filters out projects with empty DORA data', () => {
      expect(filterProjects(mockUnfilteredProjectsDoraMetrics)).toEqual(mockProjectsDoraMetrics);
    });
  });

  describe('for group', () => {
    beforeEach(() => {
      jest
        .spyOn(defaultClient, 'query')
        .mockResolvedValueOnce({ data: { project: null, group: { name: 'cool namespace' } } })
        .mockResolvedValueOnce(mockDataSourceResponses[0])
        .mockResolvedValueOnce(mockDataSourceResponses[1]);
      return fetch();
    });

    it('requests data until pagination completes', () => {
      const variables = {
        startDate: '2020-05-01',
        endDate: '2020-06-30',
        fullPath: 'cool namespace',
        interval: 'MONTHLY',
      };

      expect(defaultClient.query).toHaveBeenCalledTimes(3);
      expect(defaultClient.query).toHaveBeenCalledWith(expect.objectContaining({ variables }));
      expect(defaultClient.query).toHaveBeenCalledWith(
        expect.objectContaining({
          variables: {
            ...variables,
            after: 'page1',
          },
        }),
      );
    });

    it(`sets the visualization's tooltip`, () => {
      expect(setVisualizationOverrides).toHaveBeenCalledWith({
        visualizationOptionOverrides: {
          tooltip: expect.objectContaining({
            description: 'Showing 1 project. Excluding 1 project with no DORA metrics.',
          }),
        },
      });
    });

    it('returns filtered projects with formatted DORA metrics', () => {
      expect(res).toMatchSnapshot();
    });
  });

  describe('for project', () => {
    beforeEach(() => {
      jest
        .spyOn(defaultClient, 'query')
        .mockResolvedValueOnce({ data: { project: { name: 'cool namespace' }, group: null } });
      return fetch();
    });

    it('calls setAlerts with an error', () => {
      expect(setAlerts).toHaveBeenCalledWith({
        canRetry: false,
        title: 'Failed to load dashboard panel.',
        errors: expect.arrayContaining([
          'This visualization is not supported for project namespaces.',
        ]),
      });
    });

    it('returns undefined', () => {
      expect(res).toBeUndefined();
    });
  });
});
