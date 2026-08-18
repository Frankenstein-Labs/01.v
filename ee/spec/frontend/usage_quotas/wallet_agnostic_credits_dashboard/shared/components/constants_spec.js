import timezoneMock from 'timezone-mock';
import { useFakeDate } from 'helpers/fake_date';
import dateFormat from '~/lib/dateformat';

describe('DATE_RANGE_OPTIONS', () => {
  describe.each(['UTC', 'US/Pacific', 'US/Eastern', 'Brazil/East', 'Europe/London'])(
    '%s timezone',
    (timezone) => {
      let TODAY;
      let THIS_MONTH_OPT;
      let LAST_MONTH_OPT;
      let LAST_7_DAYS_OPT;
      let LAST_30_DAYS_OPT;
      let CUSTOM_OPT;
      beforeAll(() => {
        timezoneMock.register(timezone);
      });

      afterAll(() => {
        timezoneMock.unregister();
      });

      // Freeze on 2026-04-01 UTC
      useFakeDate(2026, 3, 1);

      beforeEach(async () => {
        jest.resetModules();
        ({
          TODAY,
          THIS_MONTH: THIS_MONTH_OPT,
          LAST_MONTH: LAST_MONTH_OPT,
          LAST_7_DAYS: LAST_7_DAYS_OPT,
          LAST_30_DAYS: LAST_30_DAYS_OPT,
          CUSTOM: CUSTOM_OPT,
        } = await import('ee/usage_quotas/wallet_agnostic_credits_dashboard/shared/components/constants'));
      });

      it('today', () => {
        const formattedValue = dateFormat(TODAY, 'yyyy-mm-dd HH:MM:ss Z', true);
        expect(formattedValue).toBe('2026-04-01 00:00:00 UTC');
      });

      it('this_month has correct UTC date range', () => {
        expect(THIS_MONTH_OPT.startDate).toBe('2026-04-01');
        expect(THIS_MONTH_OPT.endDate).toBe('2026-04-30');
      });

      it('last_month has correct UTC date range', () => {
        expect(LAST_MONTH_OPT.startDate).toBe('2026-03-01');
        expect(LAST_MONTH_OPT.endDate).toBe('2026-03-31');
      });

      it('last_7_days has correct UTC date range', () => {
        expect(LAST_7_DAYS_OPT.startDate).toBe('2026-03-25');
        expect(LAST_7_DAYS_OPT.endDate).toBe('2026-04-01');
      });

      it('last_30_days has correct UTC date range', () => {
        expect(LAST_30_DAYS_OPT.startDate).toBe('2026-03-02');
        expect(LAST_30_DAYS_OPT.endDate).toBe('2026-04-01');
      });

      it('custom option has no startDate or endDate', () => {
        expect(CUSTOM_OPT.startDate).toBeUndefined();
        expect(CUSTOM_OPT.endDate).toBeUndefined();
      });
    },
  );
});
