import {
  formatSeconds,
  runnerWaitTimeQueryData,
  runnerWaitTimeHistoryQueryData,
  runnerWaitTimeHistoryRange,
} from 'ee/ci/runner/runner_performance_utils';

import { useFakeDate } from 'helpers/fake_date';
import { I18N_MEDIAN, I18N_P75, I18N_P90, I18N_P99 } from 'ee/ci/runner/constants';

const mockSecondValues = [
  [null, '-'],
  [0.119, '0.12'],
  [0.99, '0.99'],
  [0.991, '0.99'],
  [0.999, '1.00'],
  [1, '1.00'],
  [1000, '1,000.00'],
];

describe('runner_performance_utils', () => {
  describe('formatSeconds', () => {
    it.each(mockSecondValues)('single stat, %p formatted as %p', (value, formatted) => {
      expect(formatSeconds(value)).toEqual(formatted);
    });
  });

  describe('runnerWaitTimeQueryData', () => {
    it.each([null, undefined])('%o data returns placeholders', (data) => {
      expect(runnerWaitTimeQueryData(data)).toEqual([
        { key: 'p50', title: I18N_MEDIAN, value: '-' },
        { key: 'p75', title: I18N_P75, value: '-' },
        { key: 'p90', title: I18N_P90, value: '-' },
        { key: 'p99', title: I18N_P99, value: '-' },
      ]);
    });

    it('single stat', () => {
      expect(
        runnerWaitTimeQueryData({
          p50: 50,
          __typename: 'CiJobsDurationStatistics',
        }),
      ).toEqual([{ key: 'p50', title: I18N_MEDIAN, value: '50.00' }]);
    });

    it.each(mockSecondValues)('single stat, %p formatted as %p', (value, formatted) => {
      expect(
        runnerWaitTimeQueryData({
          p50: value,
          __typename: 'CiJobsDurationStatistics',
        }),
      ).toEqual([{ key: 'p50', title: I18N_MEDIAN, value: formatted }]);
    });

    it('single stat, unknown metric name', () => {
      expect(
        runnerWaitTimeQueryData({
          'unknown metric!': 1000.01,
          __typename: 'CiJobsDurationStatistics',
        }),
      ).toEqual([{ key: 'unknown metric!', title: 'unknown metric!', value: '1,000.01' }]);
    });

    it('multiple stats', () => {
      expect(
        runnerWaitTimeQueryData({
          p50: 50,
          p75: 75,
          p90: 90,
          p99: 99,
          __typename: 'CiJobsDurationStatistics',
        }),
      ).toEqual([
        { key: 'p50', title: I18N_MEDIAN, value: '50.00' },
        { key: 'p75', title: I18N_P75, value: '75.00' },
        { key: 'p90', title: I18N_P90, value: '90.00' },
        { key: 'p99', title: I18N_P99, value: '99.00' },
      ]);
    });
  });

  describe('runnerWaitTimeHistoryQueryData', () => {
    it('empty data', () => {
      expect(runnerWaitTimeHistoryQueryData(undefined)).toEqual([]);
      expect(runnerWaitTimeHistoryQueryData([])).toEqual([]);
    });

    it('transforms a timeseries with one data point', () => {
      const data = runnerWaitTimeHistoryQueryData([
        {
          time: '2023-09-14T10:00:00Z',
          p99: 99,
          __typename: 'QueueingHistoryTimeSeries',
        },
      ]);

      expect(data).toEqual([
        {
          name: I18N_P99,
          data: [['2023-09-14T10:00:00Z', 99]],
        },
      ]);
    });

    it('transforms a timeseries with one data point, unknown series name', () => {
      const data = runnerWaitTimeHistoryQueryData([
        {
          time: '2023-09-14T10:00:00Z',
          'unknown metric!': 99,
          __typename: 'QueueingHistoryTimeSeries',
        },
      ]);

      expect(data).toEqual([
        {
          name: 'unknown metric!',
          data: [['2023-09-14T10:00:00Z', 99]],
        },
      ]);
    });

    it('3 timeseries with 2 data points', () => {
      const data = runnerWaitTimeHistoryQueryData([
        {
          time: '2023-09-14T10:00:00Z',
          p99: 99,
          p90: 90,
          p50: 50,
          __typename: 'QueueingHistoryTimeSeries',
        },
        {
          time: '2023-09-14T11:00:00Z',
          p99: 98,
          p90: 89,
          p50: 49,
          __typename: 'QueueingHistoryTimeSeries',
        },
      ]);

      expect(data).toEqual([
        {
          name: I18N_P99,
          data: [
            ['2023-09-14T10:00:00Z', 99],
            ['2023-09-14T11:00:00Z', 98],
          ],
        },
        {
          name: I18N_P90,
          data: [
            ['2023-09-14T10:00:00Z', 90],
            ['2023-09-14T11:00:00Z', 89],
          ],
        },
        {
          name: I18N_MEDIAN,
          data: [
            ['2023-09-14T10:00:00Z', 50],
            ['2023-09-14T11:00:00Z', 49],
          ],
        },
      ]);
    });
  });

  describe('runnerWaitTimeHistoryRange', () => {
    useFakeDate('2023-9-18');

    it('returns default range of three hours', () => {
      expect(runnerWaitTimeHistoryRange()).toEqual({
        fromTime: '2023-09-17T21:00:00.000Z',
        toTime: '2023-09-18T00:00:00.000Z',
      });
    });

    it('returns a range', () => {
      expect(runnerWaitTimeHistoryRange(3600)).toEqual({
        fromTime: '2023-09-17T23:00:00.000Z',
        toTime: '2023-09-18T00:00:00.000Z',
      });
    });
  });
});
