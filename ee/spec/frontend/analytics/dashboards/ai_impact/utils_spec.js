import {
  SUPPORTED_DORA_METRICS,
  SUPPORTED_FLOW_METRICS,
  TREND_STYLE_ASC,
  TREND_STYLE_DESC,
  TREND_STYLE_NONE,
} from 'ee/analytics/dashboards/constants';
import { calculateRate, generateMetricTableTooltip } from '~/analytics/dashboards/ai_impact/utils';
import {
  generateDateRanges,
  generateTableColumns,
  generateSkeletonTableData,
  calculateChange,
  generateTableRows,
  generateTableAlerts,
  getBadgeTrendIndicator,
} from 'ee/analytics/dashboards/ai_impact/utils';
import { mockTimePeriods } from './mock_data';

describe('AI impact Dashboard utils', () => {
  describe('generateDateRanges', () => {
    it.each`
      date            | description
      ${'07-01-2021'} | ${'on the first of the month'}
      ${'03-31-2021'} | ${'on the last of the month'}
      ${'03-31-2020'} | ${'in a leap year'}
    `('returns the expected date ranges $description', ({ date }) => {
      expect(generateDateRanges(new Date(date))).toMatchSnapshot();
    });
  });

  describe('generateTableColumns', () => {
    it.each`
      date            | description
      ${'07-01-2021'} | ${'on the first of the month'}
      ${'03-31-2021'} | ${'on the last of the month'}
      ${'03-31-2020'} | ${'in a leap year'}
    `('returns the expected table fields $description', ({ date }) => {
      expect(generateTableColumns(new Date(date))).toMatchSnapshot();
    });
  });

  describe('generateSkeletonTableData', () => {
    it('returns the skeleton based on the table fields', () => {
      expect(generateSkeletonTableData()).toMatchSnapshot();
    });
  });

  describe('calculateChange', () => {
    it.each`
      current      | previous     | value    | tooltip
      ${0}         | ${10}        | ${-1}    | ${undefined}
      ${0}         | ${-10}       | ${1}     | ${undefined}
      ${100}       | ${200}       | ${-0.5}  | ${undefined}
      ${0}         | ${0}         | ${0}     | ${'No change'}
      ${'0.0'}     | ${'0.0'}     | ${0}     | ${'No change'}
      ${10}        | ${10}        | ${0}     | ${'No change'}
      ${10}        | ${0}         | ${'n/a'} | ${undefined}
      ${undefined} | ${100}       | ${'n/a'} | ${"Value can't be calculated due to insufficient data."}
      ${null}      | ${100}       | ${'n/a'} | ${"Value can't be calculated due to insufficient data."}
      ${'-'}       | ${100}       | ${'n/a'} | ${"Value can't be calculated due to insufficient data."}
      ${100}       | ${undefined} | ${'n/a'} | ${"Value can't be calculated due to insufficient data."}
      ${100}       | ${null}      | ${'n/a'} | ${"Value can't be calculated due to insufficient data."}
      ${100}       | ${'-'}       | ${'n/a'} | ${"Value can't be calculated due to insufficient data."}
      ${'-'}       | ${'-'}       | ${'n/a'} | ${'No data available'}
    `(
      '($current, $previous) returns { value: $value, tooltip: `$tooltip` }',
      ({ current, previous, value, tooltip }) => {
        expect(calculateChange(current, previous)).toEqual({ value, tooltip });
      },
    );

    it.each`
      current      | previous     | tooltipType                  | value
      ${'-'}       | ${'-'}       | ${'noDataTooltip'}           | ${'n/a'}
      ${undefined} | ${100}       | ${'insufficientDataTooltip'} | ${'n/a'}
      ${100}       | ${undefined} | ${'insufficientDataTooltip'} | ${'n/a'}
      ${0}         | ${0}         | ${'noChangeTooltip'}         | ${0}
      ${10}        | ${10}        | ${'noChangeTooltip'}         | ${0}
      ${10}        | ${0}         | ${'noPreviousDataTooltip'}   | ${'n/a'}
      ${100}       | ${200}       | ${'validValueTooltip'}       | ${-0.5}
      ${0}         | ${10}        | ${'validValueTooltip'}       | ${-1}
    `(
      '($current, $previous) with custom tooltip returns { value: $value, tooltip: `custom tooltip` }',
      ({ current, previous, tooltipType, value }) => {
        expect(calculateChange(current, previous, { [tooltipType]: 'custom tooltip' })).toEqual({
          value,
          tooltip: 'custom tooltip',
        });
      },
    );

    it('preserves tooltip defaults when only one tooltip is customized', () => {
      expect(calculateChange('-', '-', { noChangeTooltip: 'custom tooltip' })).toEqual({
        value: 'n/a',
        tooltip: 'No data available',
      });
    });
  });

  describe('generateTableRows', () => {
    it('returns the data formatted as a table row', () => {
      expect(generateTableRows(mockTimePeriods)).toMatchSnapshot();
    });
  });

  describe('calculateRate', () => {
    it('returns null when counts are invalid', () => {
      expect(calculateRate({ numerator: -2, denominator: 10 })).toBeNull();
      expect(calculateRate({ numerator: 1, denominator: 0 })).toBeNull();
    });

    it('returns null when counts are zero', () => {
      expect(calculateRate({ numerator: 0, denominator: 0 })).toBeNull();
    });

    it('returns rate as percentage', () => {
      expect(calculateRate({ numerator: 3, denominator: 4 })).toBe(75);
      expect(calculateRate({ numerator: 0, denominator: 1 })).toBe(0);
    });

    it('returns rate as decimal when asDecimal=true', () => {
      expect(calculateRate({ numerator: 5, denominator: 10, asDecimal: true })).toBe(0.5);
    });
  });

  describe('generateTableAlerts', () => {
    it('returns the list of alerts that have associated metrics', () => {
      const errors = 'errors';
      const warnings = 'warnings';
      expect(
        generateTableAlerts([
          [errors, SUPPORTED_FLOW_METRICS],
          [warnings, SUPPORTED_DORA_METRICS],
          ['no error', []],
        ]),
      ).toEqual([
        `${errors}: Lead time, Cycle time, Issues created, Issues closed, Deploys, Median time to merge`,
        `${warnings}: Deployment frequency, Lead time for changes, Time to restore service, Change failure rate`,
      ]);
    });
  });

  describe('generateMetricTableTooltip', () => {
    const noDataMsg = 'No data';

    it.each`
      numerator    | denominator  | result
      ${4}         | ${5}         | ${'4/5'}
      ${0}         | ${20}        | ${'0/20'}
      ${undefined} | ${10}        | ${noDataMsg}
      ${8}         | ${undefined} | ${noDataMsg}
    `(`returns the metric table's tooltip as expected`, ({ numerator, denominator, result }) => {
      expect(generateMetricTableTooltip({ numerator, denominator })).toBe(result);
    });
  });

  describe('getBadgeTrendIndicator', () => {
    it.each`
      change   | trendStyle          | variant      | metaIcon        | metaText
      ${0.5}   | ${TREND_STYLE_ASC}  | ${'success'} | ${'trend-up'}   | ${'50.0%'}
      ${-0.5}  | ${TREND_STYLE_ASC}  | ${'danger'}  | ${'trend-down'} | ${'50.0%'}
      ${0.5}   | ${TREND_STYLE_DESC} | ${'danger'}  | ${'trend-up'}   | ${'50.0%'}
      ${-0.5}  | ${TREND_STYLE_DESC} | ${'success'} | ${'trend-down'} | ${'50.0%'}
      ${0.5}   | ${TREND_STYLE_NONE} | ${'neutral'} | ${'trend-up'}   | ${'50.0%'}
      ${-0.5}  | ${TREND_STYLE_NONE} | ${'neutral'} | ${'trend-down'} | ${'50.0%'}
      ${0}     | ${undefined}        | ${'neutral'} | ${undefined}    | ${'0%'}
      ${'n/a'} | ${undefined}        | ${'neutral'} | ${undefined}    | ${'n/a'}
    `(
      'change=$change trendStyle=$trendStyle returns variant=$variant, metaIcon=$metaIcon, metaText=$metaText',
      ({ change, trendStyle, variant, metaIcon, metaText }) => {
        expect(getBadgeTrendIndicator({ change, trendStyle })).toEqual({
          variant,
          metaIcon,
          metaText,
        });
      },
    );
  });
});
