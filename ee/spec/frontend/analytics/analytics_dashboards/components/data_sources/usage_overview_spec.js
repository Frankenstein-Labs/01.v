import {
  USAGE_OVERVIEW_METADATA,
  USAGE_OVERVIEW_IDENTIFIER_GROUPS,
  USAGE_OVERVIEW_IDENTIFIER_PROJECTS,
  USAGE_OVERVIEW_IDENTIFIER_USERS,
  USAGE_OVERVIEW_IDENTIFIER_ISSUES,
  USAGE_OVERVIEW_IDENTIFIER_MERGE_REQUESTS,
  USAGE_OVERVIEW_IDENTIFIER_PIPELINES,
} from '~/analytics/shared/constants';
import fetch, {
  prepareQuery,
  extractUsageMetrics,
  extractUsageNamespaceData,
  getMostRecentRecordedAt,
} from 'ee/analytics/analytics_dashboards/data_sources/usage_overview';
import { defaultClient } from 'ee/analytics/analytics_dashboards/graphql/client';
import {
  mockGroupUsageMetricsQueryResponse,
  mockProjectUsageMetricsQueryResponse,
  mockUsageGroupNamespaceData,
  mockGroupUsageMetrics,
  mockUsageMetricsNoData,
  mockGroupUsageOverviewData,
  mockUsageProjectNamespaceData,
  mockProjectUsageOverviewData,
  mockProjectUsageMetrics,
} from '../../mock_data';

describe('Usage overview Data Source', () => {
  let obj;

  const namespace = 'some-namespace-path';
  const queryKeys = [USAGE_OVERVIEW_IDENTIFIER_ISSUES, USAGE_OVERVIEW_IDENTIFIER_MERGE_REQUESTS];
  const mockFilters = { filters: { include: queryKeys } };
  const { group: mockGroupUsageMetricsData } = mockGroupUsageMetricsQueryResponse;
  const { project: mockProjectUsageMetricsData } = mockProjectUsageMetricsQueryResponse;
  const identifiers = [
    USAGE_OVERVIEW_IDENTIFIER_GROUPS,
    USAGE_OVERVIEW_IDENTIFIER_PROJECTS,
    USAGE_OVERVIEW_IDENTIFIER_USERS,
    USAGE_OVERVIEW_IDENTIFIER_ISSUES,
    USAGE_OVERVIEW_IDENTIFIER_MERGE_REQUESTS,
    USAGE_OVERVIEW_IDENTIFIER_PIPELINES,
  ];

  describe('extractUsageMetrics', () => {
    describe.each`
      usageOverviewType          | usageMetricsData               | expectedUsageMetrics
      ${'group usage metrics'}   | ${mockGroupUsageMetricsData}   | ${mockGroupUsageMetrics}
      ${'project usage metrics'} | ${mockProjectUsageMetricsData} | ${mockProjectUsageMetrics}
    `('for $usageOverviewType', ({ usageMetricsData, expectedUsageMetrics }) => {
      it('returns an array of metrics', () => {
        expect(extractUsageMetrics(usageMetricsData)).toEqual(expectedUsageMetrics);
      });

      it('returns all the available metrics with their metadata', () => {
        const metrics = extractUsageMetrics(usageMetricsData);

        metrics.forEach((metric) => {
          const { identifier, options } = metric;
          expect(identifiers.includes(identifier)).toBe(true);
          expect(metric.value).toBe(usageMetricsData[identifier].count);
          expect(options).toBe(USAGE_OVERVIEW_METADATA[identifier].options);
        });
      });
    });
  });

  describe('extractUsageNamespaceData', () => {
    it.each`
      namespaceType | isProjectNamespace | usageMetricsData               | expectedNamespaceData
      ${'group'}    | ${false}           | ${mockGroupUsageMetricsData}   | ${mockUsageGroupNamespaceData}
      ${'project'}  | ${true}            | ${mockProjectUsageMetricsData} | ${mockUsageProjectNamespaceData}
    `(
      'returns the $namespaceType namespace data as expected',
      ({ isProjectNamespace, usageMetricsData, expectedNamespaceData }) => {
        expect(extractUsageNamespaceData({ data: usageMetricsData, isProjectNamespace })).toEqual(
          expectedNamespaceData,
        );
      },
    );
  });

  describe('getMostRecentRecordedAt', () => {
    it('returns most recent recorded timestamp as expected', () => {
      expect(getMostRecentRecordedAt(mockGroupUsageMetrics)).toBe('Nov 27, 2023, 11:59 PM');
    });

    it.each`
      description                      | data
      ${'there is no data'}            | ${[]}
      ${'latest timestamp is invalid'} | ${[{ ...mockGroupUsageMetrics[0], recordedAt: 'invalid-timestamp' }]}
    `('returns null when $description', ({ data }) => {
      expect(getMostRecentRecordedAt(data)).toBeNull();
    });
  });

  describe('prepareQuery', () => {
    const queryIncludeKeys = [
      'includeGroups',
      'includeProjects',
      'includeUsers',
      'includeIssues',
      'includeMergeRequests',
      'includePipelines',
    ];

    it('will return all the keys we can include', () => {
      expect(Object.keys(prepareQuery())).toEqual(queryIncludeKeys);
    });

    it('will return false for every key by default', () => {
      Object.values(prepareQuery()).forEach((res) => {
        expect(res).toBe(false);
      });
    });

    it('will set keys that are explicitly included to true', () => {
      const res = prepareQuery(queryKeys);

      expect(res).toEqual({
        includeGroups: false,
        includeIssues: true,
        includeProjects: false,
        includeUsers: false,
        includeMergeRequests: true,
        includePipelines: false,
      });
    });
  });

  describe('fetch', () => {
    const setVisualizationOverrides = jest.fn();

    describe.each`
      namespaceDescription    | namespaceOverride                 | expectedNamespace
      ${'default namespace'}  | ${undefined}                      | ${namespace}
      ${'namespace override'} | ${'some-namespace-override-path'} | ${'some-namespace-override-path'}
    `('with a $namespaceDescription', ({ namespaceOverride, expectedNamespace }) => {
      it(`will request the namespace's usage overview metrics`, async () => {
        jest.spyOn(defaultClient, 'query').mockResolvedValue({ data: {} });

        obj = await fetch({
          namespace,
          query: { namespace: namespaceOverride },
          setVisualizationOverrides,
        });

        expect(defaultClient.query).toHaveBeenCalledWith(
          expect.objectContaining({
            variables: {
              fullPath: expectedNamespace,
              startDate: expect.anything(),
              endDate: expect.anything(),
              includeGroups: true,
              includeMergeRequests: true,
              includeIssues: true,
              includeProjects: true,
              includePipelines: true,
              includeUsers: true,
            },
          }),
        );
      });

      it('will only request the specified metrics', async () => {
        jest.spyOn(defaultClient, 'query').mockResolvedValue({ data: {} });

        obj = await fetch({
          namespace,
          query: {
            namespace: namespaceOverride,
            filters: { include: [USAGE_OVERVIEW_IDENTIFIER_MERGE_REQUESTS] },
          },
          setVisualizationOverrides,
        });

        expect(defaultClient.query).toHaveBeenCalledWith(
          expect.objectContaining({
            variables: {
              fullPath: expectedNamespace,
              startDate: expect.anything(),
              endDate: expect.anything(),
              includeMergeRequests: true,
              includeGroups: false,
              includeIssues: false,
              includeProjects: false,
              includePipelines: false,
              includeUsers: false,
            },
          }),
        );
      });
    });

    describe.each`
      namespaceTypeDescription    | queryResponse                           | usageOverviewData               | lastUpdated
      ${'for group namespaces'}   | ${mockGroupUsageMetricsQueryResponse}   | ${mockGroupUsageOverviewData}   | ${'Nov 27, 2023, 11:59 PM'}
      ${'for project namespaces'} | ${mockProjectUsageMetricsQueryResponse} | ${mockProjectUsageOverviewData} | ${'Nov 26, 2023, 11:59 PM'}
    `('$namespaceTypeDescription', ({ queryResponse, usageOverviewData, lastUpdated }) => {
      describe('with no data', () => {
        beforeEach(async () => {
          jest.spyOn(defaultClient, 'query').mockResolvedValue({ data: {} });

          obj = await fetch({ namespace, query: mockFilters, setVisualizationOverrides });
        });

        it('returns the no data object', () => {
          expect(obj).toMatchObject({ metrics: mockUsageMetricsNoData });
        });

        it(`sets the visualization's tooltip without last updated timestamp`, () => {
          expect(setVisualizationOverrides).toHaveBeenCalledWith({
            visualizationOptionOverrides: {
              tooltip: expect.objectContaining({
                description:
                  'Statistics on namespace usage. Usage data is a cumulative count, and updated monthly.',
              }),
            },
          });
        });
      });

      describe('successfully completes', () => {
        beforeEach(async () => {
          jest.spyOn(defaultClient, 'query').mockResolvedValue({ data: queryResponse });

          obj = await fetch({ namespace, query: mockFilters, setVisualizationOverrides });
        });

        it('will fetch the usage overview data', () => {
          expect(obj).toMatchObject(usageOverviewData);
        });

        it(`sets the visualization's tooltip with last updated timestamp`, () => {
          expect(setVisualizationOverrides).toHaveBeenCalledWith({
            visualizationOptionOverrides: {
              tooltip: expect.objectContaining({
                description: `Statistics on namespace usage. Usage data is a cumulative count, and updated monthly. Last updated: ${lastUpdated}`,
              }),
            },
          });
        });
      });
    });

    describe('with an error', () => {
      beforeEach(() => {
        jest.spyOn(defaultClient, 'query').mockRejectedValue({});

        obj = fetch({ namespace, query: mockFilters });
      });

      it('throws Error object with correct message', async () => {
        await expect(() => obj).rejects.toThrow('Failed to load usage overview data');
      });
    });
  });
});
