import { generateChartDateRangeData } from 'ee/issues_analytics/utils';

describe('Issues Analytics utils', () => {
  describe('generateChartDateRangeData', () => {
    it('returns the data as expected', () => {
      const chartDateRangeData = generateChartDateRangeData(
        new Date('2023-07-04'),
        new Date('2023-09-15'),
      );

      expect(chartDateRangeData).toEqual([
        {
          fromDate: '2023-07-04',
          toDate: '2023-08-01',
          month: 'Jul',
          year: 2023,
          identifier: 'query_2023_7',
        },
        {
          fromDate: '2023-08-01',
          toDate: '2023-09-01',
          month: 'Aug',
          year: 2023,
          identifier: 'query_2023_8',
        },
        {
          fromDate: '2023-09-01',
          toDate: '2023-09-15',
          month: 'Sep',
          year: 2023,
          identifier: 'query_2023_9',
        },
      ]);
    });

    it('does not return the final month when `endDate` is the first of the month', () => {
      const chartDateRangeData = generateChartDateRangeData(
        new Date('2023-08-04'),
        new Date('2023-09-01'),
      );

      expect(chartDateRangeData).toEqual([
        {
          fromDate: '2023-08-04',
          toDate: '2023-09-01',
          month: 'Aug',
          year: 2023,
          identifier: 'query_2023_8',
        },
      ]);
    });

    it('returns an empty array when the same date is used for `startDate`/`endDate`', () => {
      const chartDateRangeData = generateChartDateRangeData(
        new Date('2023-08-04'),
        new Date('2023-08-04'),
      );

      expect(chartDateRangeData).toEqual([]);
    });

    it('returns an empty array when `endDate` comes before `startDate`', () => {
      const chartDateRangeData = generateChartDateRangeData(
        new Date('2023-09-15'),
        new Date('2023-07-04'),
      );

      expect(chartDateRangeData).toEqual([]);
    });
  });
});
