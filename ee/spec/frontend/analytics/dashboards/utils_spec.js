import MockAdapter from 'axios-mock-adapter';
import axios from '~/lib/utils/axios_utils';
import { UNITS, FLOW_METRICS, VALUE_STREAM_METRIC_METADATA } from '~/analytics/shared/constants';
import {
  SUPPORTED_DORA_METRICS,
  SUPPORTED_FLOW_METRICS,
  SUPPORTED_VULNERABILITY_METRICS,
} from 'ee/analytics/dashboards/constants';
import { useFakeDate } from 'helpers/fake_date';
import {
  formatMetric,
  hasTrailingDecimalZero,
  buildMetricLink,
} from '~/analytics/dashboards/utils';
import {
  percentChange,
  generateSkeletonTableData,
  isMetricInTimePeriods,
  generateMetricComparisons,
  sanitizeSparklineData,
  generateSparklineCharts,
  mergeTableData,
  generateDateRanges,
  generateChartTimePeriods,
  generateDashboardTableFields,
  generateValueStreamDashboardStartDate,
  getRestrictedTableMetrics,
  generateTableAlerts,
  generateNoDataTooltip,
  getMonthsInDateRange,
} from 'ee/analytics/dashboards/utils';
import { LEAD_TIME_METRIC_TYPE, CYCLE_TIME_METRIC_TYPE } from '~/api/analytics_api';
import {
  mockMonthToDateTimePeriod,
  mockPreviousMonthTimePeriod,
  mockTwoMonthsAgoTimePeriod,
  mockThreeMonthsAgoTimePeriod,
  mockGeneratedMetricComparisons,
  mockChartsTimePeriods,
  mockChartData,
  mockSubsetChartsTimePeriods,
  mockSubsetChartData,
  MOCK_TABLE_TIME_PERIODS,
  MOCK_CHART_TIME_PERIODS,
  MOCK_DASHBOARD_TABLE_FIELDS,
} from './mock_data';

describe('Analytics Dashboards utils', () => {
  let mock;

  beforeEach(() => {
    mock = new MockAdapter(axios);
  });

  afterEach(() => {
    mock.restore();
  });

  describe('percentChange', () => {
    it.each`
      current | previous | result
      ${10}   | ${20}    | ${-0.5}
      ${5}    | ${2}     | ${1.5}
      ${5}    | ${0}     | ${0}
      ${0}    | ${5}     | ${0}
    `('calculates the percentage change given 2 numbers', ({ current, previous, result }) => {
      expect(percentChange({ current, previous })).toBe(result);
    });
  });

  describe.each([
    { units: UNITS.PER_DAY, suffix: '/d' },
    { units: UNITS.DAYS, suffix: ' d' },
    { units: UNITS.PERCENT, suffix: '%' },
    { units: UNITS.MINUTES, suffix: ' m' },
  ])('formatMetric(*, $units)', ({ units, suffix }) => {
    it.each`
      value      | result
      ${0}       | ${'0.0'}
      ${10}      | ${'10.0'}
      ${-10}     | ${'-10.0'}
      ${1}       | ${'1.0'}
      ${-1}      | ${'-1.0'}
      ${0.1}     | ${'0.1'}
      ${-0.99}   | ${'-0.99'}
      ${0.099}   | ${'0.099'}
      ${-0.01}   | ${'-0.01'}
      ${0.0099}  | ${'0.0099'}
      ${-0.0001} | ${'-0.0001'}
    `('returns $result for a metric with the value $value', ({ value, result }) => {
      expect(formatMetric(value, units)).toBe(`${result}${suffix}`);
    });
  });

  describe('formatMetric(*, BIGINT_COUNT)', () => {
    it.each`
      value      | result
      ${0}       | ${'0'}
      ${10}      | ${'10'}
      ${-10}     | ${'-10'}
      ${1}       | ${'1'}
      ${-1}      | ${'-1'}
      ${0.1}     | ${'-'}
      ${-0.99}   | ${'-'}
      ${0.099}   | ${'-'}
      ${-0.01}   | ${'-'}
      ${0.0099}  | ${'-'}
      ${-0.0001} | ${'-'}
    `('returns $result for a metric with the value $value', ({ value, result }) => {
      expect(formatMetric(value, UNITS.BIGINT_COUNT)).toBe(result);
    });
  });

  describe('hasTrailingDecimalZero', () => {
    it.each`
      value         | result
      ${'-10.0/d'}  | ${false}
      ${'0.099/d'}  | ${false}
      ${'0.0099%'}  | ${false}
      ${'0.10%'}    | ${true}
      ${'-0.010 d'} | ${true}
    `('returns $result for value $value', ({ value, result }) => {
      expect(hasTrailingDecimalZero(value)).toBe(result);
    });
  });

  describe('generateSkeletonTableData', () => {
    it('returns blank row data for each metric', () => {
      const tableData = generateSkeletonTableData();
      tableData.forEach((data) =>
        expect(Object.keys(data)).toEqual(['trendStyle', 'metric', 'valueLimit']),
      );
    });

    it('does not include metrics that were in excludeMetrics', () => {
      const excludeMetrics = [LEAD_TIME_METRIC_TYPE, CYCLE_TIME_METRIC_TYPE];
      const tableData = generateSkeletonTableData(excludeMetrics);

      const metrics = tableData.map(({ metric }) => metric.identifier);
      expect(metrics).not.toEqual(expect.arrayContaining(excludeMetrics));
    });
  });

  describe('isMetricInTimePeriods', () => {
    const timePeriods = [
      mockMonthToDateTimePeriod,
      mockPreviousMonthTimePeriod,
      mockTwoMonthsAgoTimePeriod,
      mockThreeMonthsAgoTimePeriod,
    ];

    it('returns true if the time periods reference the metric', () => {
      expect(isMetricInTimePeriods(LEAD_TIME_METRIC_TYPE, timePeriods)).toBe(true);
    });

    it('returns false if the time periods do not reference the metric', () => {
      expect(isMetricInTimePeriods('unknown', timePeriods)).toBe(false);
    });
  });

  describe('generateMetricComparisons', () => {
    const timePeriods = [
      mockMonthToDateTimePeriod,
      mockPreviousMonthTimePeriod,
      mockTwoMonthsAgoTimePeriod,
      mockThreeMonthsAgoTimePeriod,
    ];

    it('calculates the changes between the 2 time periods', () => {
      const tableData = generateMetricComparisons(timePeriods);
      expect(tableData).toEqual(mockGeneratedMetricComparisons());
    });

    it('returns the comparison table fields + metadata for each row', () => {
      Object.values(generateMetricComparisons(timePeriods)).forEach((row) => {
        expect(row).toMatchObject({
          thisMonth: expect.any(Object),
          lastMonth: expect.any(Object),
          twoMonthsAgo: expect.any(Object),
        });
      });
    });
  });

  describe('sanitizeSparklineData', () => {
    it.each`
      input        | output
      ${null}      | ${0}
      ${undefined} | ${0}
      ${'-'}       | ${null}
      ${0}         | ${0}
      ${0.1}       | ${0.1}
      ${0.01}      | ${0}
      ${0.09}      | ${0.1}
    `('for input $input, outputs $output', ({ input, output }) => {
      expect(sanitizeSparklineData(input)).toEqual(output);
    });
  });

  describe('generateSparklineCharts', () => {
    let res = {};

    beforeEach(() => {
      res = generateSparklineCharts(mockChartsTimePeriods);
    });

    it('returns the chart data for each metric', () => {
      expect(res).toEqual(mockChartData);
    });
    it('rounds deployment_frequency values to the nearest tenth', () => {
      const randomFloats = [112.32423, 54.453654236, 0.2342, 34.34082345, 9.998843, 4.44444];
      const randomFloatsRounded = randomFloats.map((f) => Math.round(f * 10) / 10);
      const mockChartsTimePeriodsWithVariedDeploys = mockChartsTimePeriods.map((p, i) => ({
        ...p,
        deployment_frequency: {
          ...p.deployment_frequency,
          value: randomFloats[i],
        },
      }));
      const sparklineDataWithRoundedDeployFrequencies = generateSparklineCharts(
        mockChartsTimePeriodsWithVariedDeploys,
      );
      const mockChartDataWithRoundedDeployFrequencies = {
        ...mockChartData,
        deployment_frequency: {
          ...mockChartData.deployment_frequency,
          chart: {
            ...mockChartData.deployment_frequency.chart,
            data: mockChartData.deployment_frequency.chart.data.map((d, i) => [
              d[0],
              randomFloatsRounded[i],
            ]),
          },
        },
      };

      expect(sparklineDataWithRoundedDeployFrequencies).toEqual(
        mockChartDataWithRoundedDeployFrequencies,
      );
    });

    describe('with metrics keys', () => {
      beforeEach(() => {
        res = generateSparklineCharts(mockSubsetChartsTimePeriods);
      });

      it('excludes missing metrics from the result', () => {
        expect(res).toEqual(mockSubsetChartData);
      });
    });
  });

  describe('mergeTableData', () => {
    it('correctly integrates existing and new data', () => {
      const newData = { chart: { data: [1, 2, 3] }, lastMonth: { test: 'test' } };
      const rowNoData = { metric: { identifier: 'noData' } };
      const rowWithData = { metric: { identifier: 'withData' } };

      expect(mergeTableData([rowNoData, rowWithData], { withData: newData })).toEqual([
        rowNoData,
        { ...rowWithData, ...newData },
      ]);
    });
  });

  describe('generateDateRanges', () => {
    it('return correct value', () => {
      const now = MOCK_TABLE_TIME_PERIODS[0].end;
      expect(generateDateRanges(now)).toEqual(MOCK_TABLE_TIME_PERIODS);
    });

    it('return incorrect value', () => {
      const now = MOCK_TABLE_TIME_PERIODS[2].start;
      expect(generateDateRanges(now)).not.toEqual(MOCK_TABLE_TIME_PERIODS);
    });

    it('returns the correct values on the 31st of the month', () => {
      expect(generateDateRanges(new Date('2020-07-31T23:59:59.000Z'))).toEqual([
        expect.objectContaining({
          key: 'thisMonth',
          label: 'Month to date',
          start: new Date('2020-07-01T00:00:00.000Z'),
          end: new Date('2020-07-31T23:59:59.000Z'),
        }),
        expect.objectContaining({
          key: 'lastMonth',
          label: 'June',
          start: new Date('2020-06-01T00:00:00.000Z'),
          end: new Date('2020-06-30T23:59:59.000Z'),
        }),
        expect.objectContaining({
          key: 'twoMonthsAgo',
          label: 'May',
          start: new Date('2020-05-01T00:00:00.000Z'),
          end: new Date('2020-05-31T23:59:59.000Z'),
        }),
        expect.objectContaining({
          key: 'threeMonthsAgo',
          label: 'April',
          start: new Date('2020-04-01T00:00:00.000Z'),
          end: new Date('2020-04-30T23:59:59.000Z'),
        }),
      ]);
    });
  });

  describe('generateChartTimePeriods', () => {
    it('return correct value', () => {
      const now = MOCK_TABLE_TIME_PERIODS[0].end;
      expect(generateChartTimePeriods(now)).toEqual(MOCK_CHART_TIME_PERIODS);
    });

    it('return incorrect value', () => {
      const now = MOCK_TABLE_TIME_PERIODS[2].start;
      expect(generateChartTimePeriods(now)).not.toEqual(MOCK_CHART_TIME_PERIODS);
    });
  });

  describe('generateDashboardTableFields', () => {
    it('return correct value', () => {
      const now = MOCK_TABLE_TIME_PERIODS[0].end;
      expect(generateDashboardTableFields(now)).toEqual(MOCK_DASHBOARD_TABLE_FIELDS);
    });

    it('return incorrect value', () => {
      const now = MOCK_TABLE_TIME_PERIODS[2].start;
      expect(generateDashboardTableFields(now)).not.toEqual(MOCK_DASHBOARD_TABLE_FIELDS);
    });
  });

  describe('generateValueStreamDashboardStartDate', () => {
    it('will return a date', () => {
      expect(generateValueStreamDashboardStartDate()).toBeInstanceOf(Date);
    });

    describe('default', () => {
      useFakeDate(2020, 4, 4);

      it('will return the correct day', () => {
        expect(generateValueStreamDashboardStartDate().toISOString()).toBe(
          '2020-05-04T00:00:00.000Z',
        );
      });
    });

    describe('on the first day of a month', () => {
      useFakeDate(2023, 6, 1);

      it('will return the previous day', () => {
        expect(generateValueStreamDashboardStartDate().toISOString()).toBe(
          '2023-06-30T00:00:00.000Z',
        );
      });
    });
  });

  describe('getRestrictedTableMetrics', () => {
    it('restricts DORA metrics when the permission is disabled', () => {
      const permissions = { readCycleAnalytics: true, readSecurityResource: true };
      expect(getRestrictedTableMetrics([], permissions)).toEqual(SUPPORTED_DORA_METRICS);
    });

    it('restricts flow metrics when the permission is disabled', () => {
      const permissions = { readDora4Analytics: true, readSecurityResource: true };
      expect(getRestrictedTableMetrics([], permissions)).toEqual(SUPPORTED_FLOW_METRICS);
    });

    it('restricts vulnerability metrics when the permission is disabled', () => {
      const permissions = { readDora4Analytics: true, readCycleAnalytics: true };
      expect(getRestrictedTableMetrics([], permissions)).toEqual(SUPPORTED_VULNERABILITY_METRICS);
    });

    it('does not restrict metrics that are already excluded', () => {
      const excludeMetrics = [
        ...SUPPORTED_DORA_METRICS.slice(1),
        ...SUPPORTED_FLOW_METRICS.slice(1),
        ...SUPPORTED_VULNERABILITY_METRICS.slice(1),
      ];
      expect(getRestrictedTableMetrics(excludeMetrics, {})).toEqual([
        SUPPORTED_DORA_METRICS[0],
        SUPPORTED_FLOW_METRICS[0],
        SUPPORTED_VULNERABILITY_METRICS[0],
      ]);
    });
  });

  describe('generateTableAlerts', () => {
    it('returns the list of alerts that have associated metrics', () => {
      const errors = 'errors';
      const warnings = 'warnings';
      expect(
        generateTableAlerts([
          [errors, SUPPORTED_FLOW_METRICS.slice(0, 2)],
          [warnings, SUPPORTED_DORA_METRICS.slice(0, 2)],
          ['no error', []],
        ]),
      ).toEqual([
        `${errors}: Lead time, Cycle time`,
        `${warnings}: Deployment frequency, Lead time for changes`,
      ]);
    });
  });

  describe('generateNoDataTooltip', () => {
    it.each([null, undefined, 0, false])(
      'returns `No data` as expected when value is %s',
      (value) => {
        expect(generateNoDataTooltip(value)).toBe('No data');
      },
    );

    it('returns null if value is present', () => {
      expect(generateNoDataTooltip(2000)).toBeNull();
    });
  });

  describe('getMonthsInDateRange', () => {
    it('returns months in date range as expected', () => {
      const startDate = new Date('2025-08-03');
      const endDate = new Date('2025-10-10');

      expect(getMonthsInDateRange(startDate, endDate)).toEqual([
        {
          fromDate: '2025-08-03',
          toDate: '2025-08-31',
          monthLabel: 'Aug 2025',
        },
        {
          fromDate: '2025-09-01',
          toDate: '2025-09-30',
          monthLabel: 'Sep 2025',
        },
        {
          fromDate: '2025-10-01',
          toDate: '2025-10-10',
          monthLabel: 'Oct 2025',
        },
      ]);
    });
  });

  describe('buildMetricLink', () => {
    const namespace = 'group/project';
    const identifier = FLOW_METRICS.ISSUES_COMPLETED;
    const { groupLink, projectLink } = VALUE_STREAM_METRIC_METADATA[identifier];
    let originalRelativeUrlRoot;

    beforeEach(() => {
      originalRelativeUrlRoot = window.gon.relative_url_root;
      window.gon.relative_url_root = '';
    });

    afterEach(() => {
      window.gon.relative_url_root = originalRelativeUrlRoot;
    });

    it('returns an empty string when the identifier has no metadata', () => {
      expect(buildMetricLink({ identifier: 'not-a-metric', isProject: false, namespace })).toBe('');
    });

    it('returns an empty string when no namespace is provided', () => {
      expect(buildMetricLink({ identifier, isProject: false, namespace: '' })).toBe('');
    });

    it('builds a group drill-down link for a group namespace', () => {
      expect(buildMetricLink({ identifier, isProject: false, namespace })).toBe(
        `/groups/${namespace}/${groupLink}`,
      );
    });

    it('builds a project drill-down link for a project namespace', () => {
      expect(buildMetricLink({ identifier, isProject: true, namespace })).toBe(
        `/${namespace}/${projectLink}`,
      );
    });

    it('prepends the relative URL root when present', () => {
      window.gon.relative_url_root = '/gitlab';

      expect(buildMetricLink({ identifier, isProject: false, namespace })).toBe(
        `/gitlab/groups/${namespace}/${groupLink}`,
      );
    });

    it('appends filter labels as label_name query params', () => {
      expect(
        buildMetricLink({ identifier, isProject: true, namespace, filterLabels: ['bug', 'flow'] }),
      ).toBe(`/${namespace}/${projectLink}?label_name[]=bug&label_name[]=flow`);
    });
  });
});
