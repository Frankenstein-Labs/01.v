import { CubeApi, HttpTransport, __setMockLoad, __setMockMetadata } from '@cubejs-client/core';
import fetch, {
  fetchFilterOptions,
} from 'ee/analytics/analytics_dashboards/data_sources/cube_analytics';
import {
  TODAY,
  SEVEN_DAYS_AGO,
} from 'ee/analytics/analytics_dashboards/components/filters/constants';
import { toISODateFormat } from '~/lib/utils/datetime_utility';
import {
  mockResultSet,
  mockFilters,
  mockTableWithLinksResultSet,
  mockResultSetWithNullValues,
  mockContinueWaitProgressResult,
  mockMetaData,
  mockFilterOptions,
} from '../../mock_data';

const mockLoad = jest.fn().mockResolvedValue(mockResultSet);
const mockMeta = jest.fn().mockResolvedValue(mockMetaData);

jest.mock('~/lib/utils/csrf', () => ({
  headerKey: 'mock-csrf-header',
  token: 'mock-csrf-token',
}));

const itSetsUpCube = () => {
  it('creates a new CubeApi connection', () => {
    expect(CubeApi).toHaveBeenCalledWith('1', { transport: {} });
  });

  it('creates a new HttpTransport with the proxy URL and csrf headers', () => {
    expect(HttpTransport).toHaveBeenCalledWith(
      expect.objectContaining({
        apiUrl: '/api/v4/projects/TEST_ID/product_analytics/request',
        headers: expect.objectContaining({
          'mock-csrf-header': 'mock-csrf-token',
        }),
      }),
    );
  });
};

describe('Cube Analytics Data Source', () => {
  const visualizationType = 'LineChart';
  const projectId = 'TEST_ID';
  const query = { measures: ['TrackedEvents.userLanguage'] };
  const cubeJsOptions = { castNumerics: true, progressCallback: expect.any(Function) };

  beforeEach(() => {
    __setMockLoad(mockLoad);
    __setMockMetadata(mockMeta);
  });

  describe('fetch', () => {
    beforeEach(() => {
      return fetch({ projectId, visualizationType, query });
    });

    itSetsUpCube();

    it('loads the query with the provided measures and default filters', () => {
      expect(mockLoad).toHaveBeenCalledWith(expect.objectContaining(query), cubeJsOptions);
    });

    it('loads the query with the default 7 days date range filters', () => {
      const defaultFilters = {
        filters: [
          {
            member: 'TrackedEvents.derivedTstamp',
            operator: 'inDateRange',
            values: [toISODateFormat(SEVEN_DAYS_AGO), toISODateFormat(TODAY)],
          },
        ],
      };

      expect(mockLoad).toHaveBeenCalledWith(expect.objectContaining(defaultFilters), cubeJsOptions);
    });
  });

  describe('when server sends "continue wait" progressResults', () => {
    beforeEach(() => {
      mockLoad.mockImplementation((_query, cubeOptions) => {
        const { progressCallback } = cubeOptions;

        progressCallback(mockContinueWaitProgressResult);

        return Promise.resolve(mockResultSet);
      });
    });

    it('calls the "onRequestDelayed" callback', () => {
      const mockOnRequestDelayed = jest.fn();
      fetch({
        visualizationType,
        query,
        onRequestDelayed: mockOnRequestDelayed,
      });

      expect(mockOnRequestDelayed).toHaveBeenCalledTimes(1);
    });
  });

  describe('formats the data', () => {
    describe('charts', () => {
      it('returns the expected data format for line charts', async () => {
        const result = await fetch({ visualizationType, query });

        expect(result[0]).toMatchObject({
          data: [
            ['2022-11-09T00:00:00.000', 55],
            ['2022-11-10T00:00:00.000', 14],
          ],
          name: 'pageview, TrackedEvents Count',
        });
      });

      it('returns the expected data format for column charts', async () => {
        const result = await fetch({
          visualizationType: 'ColumnChart',
          query,
        });

        expect(result[0]).toMatchObject({
          data: [
            ['2022-11-09T00:00:00.000', 55],
            ['2022-11-10T00:00:00.000', 14],
          ],
          name: 'pageview, TrackedEvents Count',
        });
      });
    });

    describe('data tables', () => {
      it('returns the expected data format', async () => {
        const { nodes } = await fetch({
          visualizationType: 'DataTable',
          query,
        });

        expect(nodes[0]).toMatchObject({
          count: '55',
          event_type: 'pageview',
          utc_time: '2022-11-09T00:00:00.000',
        });
      });

      describe('with links config', () => {
        beforeEach(() => mockLoad.mockResolvedValue(mockTableWithLinksResultSet));

        it('returns the expected data format when href is a single dimension', async () => {
          const { nodes } = await fetch({
            visualizationType: 'DataTable',
            query: {
              measures: ['TrackedEvents.pageViewsCount'],
              dimensions: ['TrackedEvents.docPath', 'TrackedEvents.url'],
            },
            visualizationOptions: {
              links: [
                {
                  text: 'TrackedEvents.docPath',
                  href: 'TrackedEvents.url',
                },
              ],
            },
          });

          expect(nodes[0]).toMatchObject({
            page_views_count: '1',
            doc_path: {
              text: '/foo',
              href: 'https://example.com/foo',
            },
          });
        });

        it('returns the expected data format when href is an array of dimensions', async () => {
          const { nodes } = await fetch({
            visualizationType: 'DataTable',
            query: {
              measures: ['TrackedEvents.pageViewsCount'],
              dimensions: ['TrackedEvents.docPath', 'TrackedEvents.url'],
            },
            visualizationOptions: {
              links: [
                {
                  text: 'TrackedEvents.docPath',
                  href: ['TrackedEvents.url', 'TrackedEvents.docPath'],
                },
              ],
            },
          });

          expect(nodes[0]).toMatchObject({
            page_views_count: '1',
            doc_path: {
              text: '/foo',
              href: 'https://example.com/foo/foo',
            },
          });
        });
      });
    });

    describe('single stats', () => {
      it('returns the expected data format', async () => {
        mockLoad.mockResolvedValue(mockResultSet);
        const result = await fetch({
          visualizationType: 'SingleStat',
          query: { measures: ['TrackedEvents.count'] },
        });

        expect(result).toBe('36');
      });

      it('returns the expected data format with custom measure', async () => {
        mockLoad.mockResolvedValue(mockResultSet);
        const override = { measures: ['TrackedEvents.url'] };
        const result = await fetch({
          visualizationType: 'SingleStat',
          query: { ...query, ...override },
        });

        expect(result).toBe('https://example.com/us');
      });

      it('returns 0 when the measure is null', async () => {
        mockLoad.mockResolvedValue(mockResultSetWithNullValues);

        const result = await fetch({
          visualizationType: 'SingleStat',
          query,
        });

        expect(result).toBe(0);
      });

      it('returns 0 when data is empty', async () => {
        mockLoad.mockResolvedValue({
          rawData: () => [],
        });

        const result = await fetch({
          visualizationType: 'SingleStat',
          query,
        });

        expect(result).toBe(0);
      });
    });
  });

  describe('fetch with filters', () => {
    const existingFilters = [
      {
        operator: 'equals',
        values: ['pageview'],
        member: 'TrackedEvents.eventType',
      },
    ];

    const fetchWithFilters = (measure, filters) =>
      fetch({
        visualizationType,
        query: {
          filters: existingFilters,
          measures: [measure],
        },
        filters,
      });

    beforeEach(() => mockLoad.mockResolvedValue(mockResultSet));

    it.each`
      type               | queryMeasurement                 | expectedDimension
      ${'TrackedEvents'} | ${'TrackedEvents.pageViewCount'} | ${'TrackedEvents.derivedTstamp'}
      ${'Sessions'}      | ${'Sessions.pageViewCount'}      | ${'Sessions.startAt'}
      ${'DynamicSchema'} | ${'DynamicSchema.count'}         | ${'DynamicSchema.date'}
    `(
      'loads the query with date range filters for "$type"',
      async ({ queryMeasurement, expectedDimension }) => {
        await fetchWithFilters(queryMeasurement, mockFilters);

        expect(mockLoad).toHaveBeenCalledWith(
          expect.objectContaining({
            filters: [
              ...existingFilters,
              {
                member: expectedDimension,
                operator: 'inDateRange',
                values: [
                  toISODateFormat(mockFilters.startDate),
                  toISODateFormat(mockFilters.endDate),
                ],
              },
            ],
          }),
          cubeJsOptions,
        );
      },
    );

    describe('filtering anon users', () => {
      it.each`
        type                | queryMeasurement                  | expectedSegments
        ${'TrackedEvents'}  | ${'TrackedEvents.pageViewCount'}  | ${{ segments: ['TrackedEvents.knownUsers'] }}
        ${'Sessions'}       | ${'Sessions.pageViewCount'}       | ${{}}
        ${'ReturningUsers'} | ${'ReturningUsers.pageViewCount'} | ${{}}
      `(
        'segments the query with "$expectedSegments" for "$type"',
        async ({ queryMeasurement, expectedSegments }) => {
          await fetchWithFilters(queryMeasurement, { filterAnonUsers: true });

          expect(mockLoad).toHaveBeenCalledWith(
            {
              filters: expect.arrayContaining(existingFilters),
              measures: [queryMeasurement],
              ...expectedSegments,
            },
            cubeJsOptions,
          );
        },
      );
    });
  });

  describe('fetch filter options', () => {
    let filterOptions = {};

    beforeEach(async () => {
      filterOptions = await fetchFilterOptions(projectId);
    });

    itSetsUpCube();

    it('return formatted filter options', () => {
      expect(mockMeta).toHaveBeenCalled();
      expect(filterOptions).toStrictEqual(mockFilterOptions);
    });
  });
});
