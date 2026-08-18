import { groupUsageDataByYear } from 'ee/usage_quotas/pipelines/namespace/utils';
import { mockGetNamespaceCiMinutesUsage } from './mock_data';

const {
  data: {
    ciMinutesUsage: { nodes },
  },
} = mockGetNamespaceCiMinutesUsage;

describe('Compute minutes Usage Utils', () => {
  it('groupUsageDataByYear normalizes data by year', () => {
    const expectedDataByYear = {
      2021: [
        {
          date: new Date('2021-01-01'),
          day: '01',
          month: 'Jan',
          year: '2021',
          monthIso8601: '2021-01-01',
          minutes: 5,
          sharedRunnersDuration: 60,
        },
      ],
      2022: [
        {
          date: new Date('2022-06-01'),
          day: '01',
          month: 'June',
          year: '2022',
          monthIso8601: '2022-06-01',
          minutes: 0,
          sharedRunnersDuration: 0,
        },
        {
          date: new Date('2022-07-01'),
          day: '01',
          month: 'July',
          year: '2022',
          monthIso8601: '2022-07-01',
          minutes: 5,
          sharedRunnersDuration: 60,
        },
        {
          date: new Date('2022-08-01'),
          day: '01',
          month: 'August',
          year: '2022',
          monthIso8601: '2022-08-01',
          minutes: 7,
          sharedRunnersDuration: 80,
        },
      ],
    };

    expect(groupUsageDataByYear(nodes)).toEqual(expectedDataByYear);
  });
});
