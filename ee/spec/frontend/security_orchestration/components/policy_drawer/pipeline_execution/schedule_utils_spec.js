import {
  generateScheduleSummary,
  getBranchInfo,
  getTimeInfo,
  getTimezoneInfo,
  getWeeklyScheduleInfo,
  getMonthlyScheduleInfo,
  getScheduleTypeInfo,
  getSnoozeInfo,
} from 'ee/security_orchestration/components/policy_drawer/pipeline_execution/schedule_utils';

import {
  DAILY,
  WEEKLY,
  MONTHLY,
} from 'ee/security_orchestration/components/policy_editor/pipeline_execution/constants';
import {
  ALL_BRANCHES,
  ALL_PROTECTED_BRANCHES,
  PROJECT_DEFAULT_BRANCH,
} from 'ee/security_orchestration/components/policy_editor/constants';

describe('getBranchInfo', () => {
  it.each([undefined, null, ''])('returns empty string when branch type is $input', (input) => {
    expect(getBranchInfo(input)).toContain(PROJECT_DEFAULT_BRANCH.text);
  });

  it.each`
    input                           | output
    ${ALL_PROTECTED_BRANCHES.value} | ${ALL_PROTECTED_BRANCHES.text}
    ${PROJECT_DEFAULT_BRANCH.value} | ${PROJECT_DEFAULT_BRANCH.text}
    ${ALL_BRANCHES.value}           | ${ALL_BRANCHES.text}
    ${'custom'}                     | ${'custom'}
  `('formats branch type $input correctly', ({ input, output }) => {
    expect(getBranchInfo(input)).toContain(output);
  });
});

describe('getTimeInfo', () => {
  it.each([undefined, null, ''])('returns empty string when time is $input', (input) => {
    expect(getTimeInfo(input)).toBe('');
  });

  it.each`
    input      | output
    ${'00:00'} | ${'00:00'}
    ${'12:30'} | ${'12:30'}
    ${'23:59'} | ${'23:59'}
  `('formats time $input correctly', ({ input, output }) => {
    expect(getTimeInfo(input)).toContain(output);
  });
});

describe('getTimezoneInfo', () => {
  it.each`
    input                 | output
    ${undefined}          | ${'Etc/UTC'}
    ${null}               | ${'Etc/UTC'}
    ${''}                 | ${'Etc/UTC'}
    ${'Etc/UTC'}          | ${'Etc/UTC'}
    ${'America/New_York'} | ${'America/New_York'}
    ${'Europe/London'}    | ${'Europe/London'}
    ${'Asia/Tokyo'}       | ${'Asia/Tokyo'}
  `('formats timezone $input correctly', ({ input, output }) => {
    expect(getTimezoneInfo(input)).toContain(output);
  });
});

describe('getWeeklyScheduleInfo', () => {
  it.each`
    input           | output
    ${{}}           | ${'weekly'}
    ${{ days: [] }} | ${'weekly'}
  `('returns weekly text when days are $input', ({ input, output }) => {
    expect(getWeeklyScheduleInfo(input)).toBe(output);
  });

  it.each`
    days                                 | expectedText
    ${['Monday']}                        | ${'starting every Monday'}
    ${['Thursday']}                      | ${'starting every Thursday'}
    ${['Monday', 'Thursday']}            | ${'starting every Monday, Thursday'}
    ${['Monday', 'Wednesday', 'Friday']} | ${'starting every Monday, Wednesday, Friday'}
  `('formats days $days correctly', ({ days, expectedText }) => {
    expect(getWeeklyScheduleInfo(days)).toContain(expectedText);
  });
});

describe('getMonthlyScheduleInfo', () => {
  it.each([{}, [], undefined])('returns monthly text when days are $input', (input) => {
    expect(getMonthlyScheduleInfo(input)).toBe('monthly');
  });

  it.each`
    days           | expectedText
    ${[1]}         | ${'day 1 of each month'}
    ${[15]}        | ${'day 15 of each month'}
    ${[1, 15]}     | ${'days 1, 15 of each month'}
    ${[1, 15, 30]} | ${'days 1, 15, 30 of each month'}
  `('formats days_of_month $days correctly', ({ days, expectedText }) => {
    expect(getMonthlyScheduleInfo(days)).toContain(expectedText);
  });
});

describe('getScheduleTypeInfo', () => {
  it.each(['unknown', undefined, null])(
    'returns empty string for schedule type $input',
    (input) => {
      expect(getScheduleTypeInfo({ type: input })).toBe('');
    },
  );

  it('returns daily info for daily schedule', () => {
    expect(getScheduleTypeInfo({ type: DAILY })).toBe('daily');
  });

  it.each`
    days                      | expectedText
    ${[]}                     | ${'weekly'}
    ${['Monday']}             | ${'starting every Monday'}
    ${['Monday', 'Thursday']} | ${'starting every Monday, Thursday'}
  `('formats weekly schedule with days $days correctly', ({ days, expectedText }) => {
    const schedule = { type: WEEKLY, days };
    expect(getScheduleTypeInfo(schedule)).toBe(expectedText);
  });

  it.each`
    days       | expectedText
    ${[]}      | ${'monthly'}
    ${[15]}    | ${'on day 15 of each month'}
    ${[1, 15]} | ${'on days 1, 15 of each month'}
  `('formats monthly schedule with days $days correctly', ({ days, expectedText }) => {
    const schedule = { type: MONTHLY, days_of_month: days };
    expect(getScheduleTypeInfo(schedule)).toBe(expectedText);
  });
});

describe('getSnoozeInfo', () => {
  it.each([undefined, null])('returns empty string when snooze info is %s', (snooze) => {
    expect(getSnoozeInfo({ snooze })).toBe('');
  });

  it.each`
    snooze                                                                 | expectedText
    ${{ until: '2025-06-26T16:27:00+00:00', reason: 'under maintenance' }} | ${'The schedule is snoozed until Jun 26, 2025 4:27pm UTC for reason: under maintenance.'}
    ${{ until: '2025-06-26T16:27:00+00:00' }}                              | ${'The schedule is snoozed until Jun 26, 2025 4:27pm UTC.'}
  `('formats snooze info correctly for $snooze', ({ snooze, expectedText }) => {
    expect(getSnoozeInfo({ snooze })).toBe(expectedText);
  });
});

describe('generateScheduleSummary', () => {
  it.each`
    schedule | expectedParts
    ${{
      type: DAILY,
      branch_type: ALL_PROTECTED_BRANCHES.value,
      start_time: '12:00',
      time_window: { value: 3600 },
      timezone: 'UTC',
    }} | ${[ALL_PROTECTED_BRANCHES.text, 'daily', '12:00', '1 hour', 'UTC']}
    ${{
      type: WEEKLY,
      branch_type: PROJECT_DEFAULT_BRANCH.value,
      days: ['Monday', 'Wednesday'],
      start_time: '09:30',
      time_window: { value: 7200 },
      timezone: 'America/New_York',
    }} | ${[PROJECT_DEFAULT_BRANCH.text, 'Monday, Wednesday', '09:30', '2 hours', 'America/New_York']}
    ${{
      type: MONTHLY,
      branch_type: ALL_BRANCHES.value,
      days_of_month: [1, 15],
      start_time: '00:00',
      time_window: { value: 5400 },
      timezone: 'Europe/London',
    }} | ${[ALL_BRANCHES.text, '1, 15', '00:00', '1 hour', '30 minutes', 'Europe/London']}
    ${{
      type: DAILY,
      start_time: '12:00',
    }} | ${['daily', '12:00']}
  `('generates correct summary for $schedule.type schedule', ({ schedule, expectedParts }) => {
    const result = generateScheduleSummary(schedule);

    expectedParts.forEach((part) => {
      expect(result).toContain(part);
    });

    expect(result).not.toContain('undefined');
  });

  it.each`
    schedule | expectedParts
    ${{
      type: DAILY,
      start_time: '12:00',
    }} | ${['daily', '12:00']}
    ${{
      type: DAILY,
      start_time: '12:00',
    }} | ${['daily', '12:00']}
  `('generates correct summary for schedule with snooze info', ({ schedule, expectedParts }) => {
    const result = generateScheduleSummary(schedule);

    expectedParts.forEach((part) => {
      expect(result).toContain(part);
    });

    expect(result).not.toContain('undefined');
  });
});
