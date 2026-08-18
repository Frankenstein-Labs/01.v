import {
  formatVulnerabilitiesBySeries,
  constructVulnerabilitiesReportWithFiltersPath,
  generateGrid,
  getSeverityColors,
} from 'ee/security_dashboard/utils/chart_utils';
import * as CssUtils from '~/lib/utils/css_utils';

describe('Security Dashboard - Chart Utils', () => {
  const severities = ['Critical', 'High', 'Medium', 'Low', 'Info', 'Unknown'];
  const reportTypes = [
    'SAST',
    'Dependency Scanning',
    'Container Scanning',
    'DAST',
    'Secret Detection',
    'Coverage Fuzzing',
    'API Fuzzing',
    'Cluster Image Scanning',
    'Container Scanning for Registry',
    'Manually added',
  ];

  const mockVulnerabilitiesData = [
    {
      date: '2024-01-01',
      bySeverity: [
        { severity: 'CRITICAL', count: 5 },
        { severity: 'HIGH', count: 10 },
        { severity: 'MEDIUM', count: 15 },
      ],
      byReportType: [
        { reportType: 'SAST', count: 8 },
        { reportType: 'DEPENDENCY_SCANNING', count: 12 },
        { reportType: 'CONTAINER_SCANNING', count: 10 },
        { reportType: 'SECRET_DETECTION', count: 2 },
        { reportType: 'COVERAGE_FUZZING', count: 4 },
        { reportType: 'CLUSTER_IMAGE_SCANNING', count: 6 },
        { reportType: 'CONTAINER_SCANNING_FOR_REGISTRY', count: 8 },
        { reportType: 'GENERIC', count: 10 },
      ],
    },
    {
      date: '2024-01-02',
      bySeverity: [
        { severity: 'CRITICAL', count: 3 },
        { severity: 'HIGH', count: 8 },
        { severity: 'LOW', count: 12 },
        { severity: 'INFO', count: 2 },
        { severity: 'UNKNOWN', count: 4 },
      ],
      byReportType: [
        { reportType: 'DAST', count: 5 },
        { reportType: 'API_FUZZING', count: 3 },
        { reportType: 'SAST', count: 6 },
      ],
    },
  ];

  const getSeriesByName = (name, result) => result.find((series) => series.name === name);
  const getSeriesNames = (result) => result.map((series) => series.name);

  describe('formatVulnerabilitiesBySeries', () => {
    describe('when groupBy is "severity" (default)', () => {
      it.each(severities)('includes the correct id for "%s"', (severity) => {
        const result = formatVulnerabilitiesBySeries(mockVulnerabilitiesData);

        expect(getSeriesByName(severity, result).id).toEqual(severity.toUpperCase());
      });

      it('includes correct data points for all severities', () => {
        const result = formatVulnerabilitiesBySeries(mockVulnerabilitiesData);

        expect(getSeriesNames(result)).toEqual(severities);
        expect(getSeriesByName('Critical', result).data).toEqual([
          ['2024-01-01', 5],
          ['2024-01-02', 3],
        ]);
        expect(getSeriesByName('High', result).data).toEqual([
          ['2024-01-01', 10],
          ['2024-01-02', 8],
        ]);
      });

      it('handles edge cases correctly', () => {
        const edgeCaseData = [
          {
            date: '2024-01-01',
            bySeverity: [
              { severity: 'CRITICAL', count: 0 },
              { severity: 'nonexistent', count: 3 },
            ],
          },
          {
            date: '2024-01-02',
            bySeverity: [],
          },
        ];

        const result = formatVulnerabilitiesBySeries(edgeCaseData);

        expect(getSeriesByName('Critical', result).data).toEqual([['2024-01-01', 0]]);
        expect(getSeriesByName('nonexistent', result)).toBeUndefined();
      });
    });

    describe('when groupBy is "reportType"', () => {
      it('includes correct data points for all report types', () => {
        const result = formatVulnerabilitiesBySeries(mockVulnerabilitiesData, {
          groupBy: 'reportType',
        });

        expect(getSeriesNames(result)).toEqual(reportTypes);
        expect(getSeriesByName('SAST', result).data).toEqual([
          ['2024-01-01', 8],
          ['2024-01-02', 6],
        ]);
        expect(getSeriesByName('DAST', result).data).toEqual([['2024-01-02', 5]]);
      });

      it('handles edge cases correctly', () => {
        const edgeCaseData = [
          {
            date: '2024-01-01',
            byReportType: [
              { reportType: 'SAST', count: 0 },
              { reportType: 'nonexistent', count: 3 },
            ],
          },
          {
            date: '2024-01-02',
            byReportType: [],
          },
        ];

        const result = formatVulnerabilitiesBySeries(edgeCaseData, { groupBy: 'reportType' });

        expect(getSeriesByName('SAST', result).data).toEqual([['2024-01-01', 0]]);
        expect(getSeriesByName('nonexistent', result)).toBeUndefined();
      });
    });

    describe('groupBy parameter behavior', () => {
      it('defaults to "severity" when no groupBy is provided', () => {
        const result = formatVulnerabilitiesBySeries(mockVulnerabilitiesData);
        expect(getSeriesNames(result)).toEqual(severities);
      });

      it('uses "reportType" when groupBy is set to "reportType"', () => {
        const result = formatVulnerabilitiesBySeries(mockVulnerabilitiesData, {
          groupBy: 'reportType',
        });
        expect(getSeriesNames(result)).toEqual(reportTypes);
      });
    });

    describe('input validation', () => {
      it.each([[], null, undefined])('returns an empty array when the input is "%s"', (input) => {
        expect(formatVulnerabilitiesBySeries(input)).toEqual([]);
        expect(formatVulnerabilitiesBySeries(input, { group: 'reportType' })).toEqual([]);
      });
    });

    describe('when isStacked is true', () => {
      it('includes correct data points (with only count) for severities', () => {
        const result = formatVulnerabilitiesBySeries(mockVulnerabilitiesData, { isStacked: true });

        expect(getSeriesNames(result)).toEqual(severities);
        expect(getSeriesByName('Critical', result).data).toEqual([5, 3]);
        expect(getSeriesByName('High', result).data).toEqual([10, 8]);
      });

      it('includes correct data points (with only count) for report types', () => {
        const result = formatVulnerabilitiesBySeries(mockVulnerabilitiesData, {
          groupBy: 'reportType',
          isStacked: true,
        });

        expect(getSeriesNames(result)).toEqual(reportTypes);
        expect(getSeriesByName('SAST', result).data).toEqual([8, 6]);
        expect(getSeriesByName('DAST', result).data).toEqual([5]);
      });
    });
  });

  describe('constructVulnerabilitiesReportWithFiltersPath', () => {
    const securityVulnerabilitiesPath = '/security/vulnerabilities';

    it('constructs path with filter key and series ID', () => {
      const result = constructVulnerabilitiesReportWithFiltersPath({
        seriesId: 'SAST',
        filterKey: 'report_type',
        securityVulnerabilitiesPath,
      });

      expect(result).toBe(`${securityVulnerabilitiesPath}?report_type=SAST`);
    });

    describe('special cases', () => {
      it('constructs path with operational tab suffix', () => {
        const result = constructVulnerabilitiesReportWithFiltersPath({
          seriesId: 'CLUSTER_IMAGE_SCANNING',
          securityVulnerabilitiesPath,
        });

        expect(result).toBe(`${securityVulnerabilitiesPath}?tab=OPERATIONAL`);
      });
    });

    describe('additional filters', () => {
      it('includes additional filters when provided', () => {
        const result = constructVulnerabilitiesReportWithFiltersPath({
          seriesId: 'CRITICAL',
          filterKey: 'severity',
          securityVulnerabilitiesPath,
          additionalFilters: {
            projectId: '123',
          },
        });

        expect(result).toBe(`${securityVulnerabilitiesPath}?severity=CRITICAL&projectId=123`);
      });

      it('joins multiple values of the same filter key with commas', () => {
        const result = constructVulnerabilitiesReportWithFiltersPath({
          seriesId: 'CRITICAL',
          filterKey: 'severity',
          securityVulnerabilitiesPath,
          additionalFilters: {
            reportType: ['SAST', 'DAST'],
            projectId: '123',
          },
        });

        expect(result).toBe(
          `${securityVulnerabilitiesPath}?severity=CRITICAL&reportType=SAST%2CDAST&projectId=123`,
        );
      });

      it('skips additional filters that match the filterKey', () => {
        const filterKey = 'severity';

        const result = constructVulnerabilitiesReportWithFiltersPath({
          seriesId: 'CRITICAL',
          filterKey,
          securityVulnerabilitiesPath,
          additionalFilters: {
            [filterKey]: ['HIGH', 'MEDIUM'],
            reportType: ['SAST'],
          },
        });

        expect(result).toBe(`${securityVulnerabilitiesPath}?severity=CRITICAL&reportType=SAST`);
      });

      it('excludes securityAttributesFilters from the URL params', () => {
        const result = constructVulnerabilitiesReportWithFiltersPath({
          seriesId: 'CRITICAL',
          filterKey: 'severity',
          securityVulnerabilitiesPath,
          additionalFilters: {
            reportType: ['SAST'],
            securityAttributesFilters: [{ operator: 'IS_ONE_OF', attributes: ['gid://1'] }],
          },
        });

        expect(result).toBe(`${securityVulnerabilitiesPath}?severity=CRITICAL&reportType=SAST`);
      });

      it('skips empty additional filters', () => {
        const result = constructVulnerabilitiesReportWithFiltersPath({
          seriesId: 'CRITICAL',
          filterKey: 'severity',
          securityVulnerabilitiesPath,
          additionalFilters: {
            reportType: [],
            projectId: '',
          },
        });

        expect(result).toBe(`${securityVulnerabilitiesPath}?severity=CRITICAL`);
      });

      it.each`
        description                  | additionalFilters                                                                                                            | expectedQuery
        ${'an array of GraphQL IDs'} | ${{ trackedRefIds: ['gid://gitlab/Security::ProjectTrackedContext/25', 'gid://gitlab/Security::ProjectTrackedContext/26'] }} | ${'trackedRefIds=25%2C26'}
        ${'a scalar GraphQL ID'}     | ${{ trackedRefId: 'gid://gitlab/Security::ProjectTrackedContext/25' }}                                                       | ${'trackedRefId=25'}
      `(
        'converts $description to numeric IDs in URL params',
        ({ additionalFilters, expectedQuery }) => {
          const result = constructVulnerabilitiesReportWithFiltersPath({
            seriesId: 'CRITICAL',
            filterKey: 'severity',
            securityVulnerabilitiesPath,
            additionalFilters,
          });

          expect(result).toBe(`${securityVulnerabilitiesPath}?severity=CRITICAL&${expectedQuery}`);
        },
      );

      it('leaves non-gid string values unchanged', () => {
        const result = constructVulnerabilitiesReportWithFiltersPath({
          seriesId: 'CRITICAL',
          filterKey: 'severity',
          securityVulnerabilitiesPath,
          additionalFilters: {
            reportType: ['SAST', 'DAST'],
          },
        });

        expect(result).toBe(
          `${securityVulnerabilitiesPath}?severity=CRITICAL&reportType=SAST%2CDAST`,
        );
      });
    });
  });

  describe('generateGrid', () => {
    it('should return null for invalid input', () => {
      expect(generateGrid({ totalItems: 0, width: 100, height: 100 })).toBeNull();
      expect(generateGrid({ totalItems: -1, width: 100, height: 100 })).toBeNull();
    });

    it('should return rows and cols', () => {
      const result = generateGrid({ totalItems: 10, width: 400, height: 300 });

      expect(result).toHaveProperty('rows');
      expect(result).toHaveProperty('cols');
      expect(typeof result.rows).toBe('number');
      expect(typeof result.cols).toBe('number');
    });

    it('should have enough cells for all items', () => {
      const testCases = [
        { totalItems: 1, width: 100, height: 100 },
        { totalItems: 10, width: 400, height: 300 },
        { totalItems: 24, width: 800, height: 600 },
        { totalItems: 100, width: 1000, height: 1000 },
      ];

      testCases.forEach((params) => {
        const result = generateGrid(params);
        expect(result.rows * result.cols).toBeGreaterThanOrEqual(params.totalItems);
      });
    });

    it('should minimize empty cells', () => {
      const result = generateGrid({ totalItems: 10, width: 100, height: 100 });
      const totalCells = result.rows * result.cols;
      const emptyCells = totalCells - 10;

      // Should not have more empty cells than a full row or column
      expect(emptyCells).toBeLessThan(Math.max(result.rows, result.cols));
    });

    it('should prefer high utilization', () => {
      // For 10 items, should prefer 3x4=12 over 4x4=16
      const result = generateGrid({ totalItems: 10, width: 400, height: 300 });
      const totalCells = result.rows * result.cols;

      expect(totalCells).toBeLessThanOrEqual(12);
    });

    it('should handle perfect squares optimally', () => {
      const result = generateGrid({ totalItems: 16, width: 400, height: 400 });

      expect(result).toEqual({ rows: 4, cols: 4 });
    });

    it('should adapt to container aspect ratio', () => {
      const wideResult = generateGrid({ totalItems: 12, width: 600, height: 200 });
      const tallResult = generateGrid({ totalItems: 12, width: 200, height: 600 });

      // Wide container should have more columns than rows
      expect(wideResult.cols).toBeGreaterThan(wideResult.rows);

      // Tall container should have more rows than columns
      expect(tallResult.rows).toBeGreaterThan(tallResult.cols);
    });

    it('should return consistent results', () => {
      const params = { totalItems: 24, width: 800, height: 600 };

      const result1 = generateGrid(params);
      const result2 = generateGrid(params);

      expect(result1).toEqual(result2);
    });
  });

  describe('getSeverityColors', () => {
    it('returns an object with severities as keys and their colors as values', () => {
      jest
        .spyOn(CssUtils, 'getCssVariable')
        .mockImplementation((customProperty) => `#${customProperty}`);

      expect(getSeverityColors()).toEqual({
        critical: '#--severity-color-critical',
        high: '#--severity-color-high',
        medium: '#--severity-color-medium',
        low: '#--severity-color-low',
        info: '#--severity-color-info',
        unknown: '#--severity-color-unknown',
      });
    });
  });
});
