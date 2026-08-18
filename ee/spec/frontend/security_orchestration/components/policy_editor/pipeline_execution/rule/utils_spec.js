import { updateScheduleCadence } from 'ee/security_orchestration/components/policy_editor/pipeline_execution/rule/utils';

describe('Pipeline execution rule utils', () => {
  describe('updateScheduleCadence', () => {
    const baseSchedule = {
      start_time: '00:00',
      time_window: { value: 3600, distribution: 'random' },
      timezone: 'America/New_York',
    };

    const dailySchedule = {
      type: 'daily',
      ...baseSchedule,
    };

    const weeklySchedule = {
      type: 'weekly',
      days: ['Monday'],
      ...baseSchedule,
    };

    const monthlySchedule = {
      type: 'monthly',
      days_of_month: [1],
      ...baseSchedule,
    };

    it('updates to daily cadence correctly', () => {
      expect(updateScheduleCadence({ schedule: weeklySchedule, cadence: 'daily' })).toEqual(
        expect.objectContaining({
          ...dailySchedule,
          time_window: { value: 60, distribution: 'random' },
        }),
      );
    });

    it('updates to weekly cadence correctly', () => {
      expect(updateScheduleCadence({ schedule: monthlySchedule, cadence: 'weekly' })).toEqual(
        expect.objectContaining({
          ...weeklySchedule,
          time_window: { value: 86400, distribution: 'random' },
        }),
      );
    });

    it('updates to monthly cadence correctly', () => {
      expect(updateScheduleCadence({ schedule: dailySchedule, cadence: 'monthly' })).toEqual(
        expect.objectContaining({
          ...monthlySchedule,
          time_window: { value: 86400, distribution: 'random' },
        }),
      );
    });

    it('removes irrelevant properties when changing cadence type', () => {
      const result = updateScheduleCadence({
        schedule: baseSchedule,
        cadence: 'weekly',
      });

      expect(result).toHaveProperty('days');
      expect(result).not.toHaveProperty('days_of_month');
    });

    it('preserves additional properties not related to cadence', () => {
      const scheduleWithExtra = {
        ...baseSchedule,
        custom_property: 'value',
        another_property: 123,
      };

      const result = updateScheduleCadence({
        schedule: scheduleWithExtra,
        cadence: 'weekly',
      });

      expect(result.custom_property).toBe('value');
      expect(result.another_property).toBe(123);
    });
  });
});
