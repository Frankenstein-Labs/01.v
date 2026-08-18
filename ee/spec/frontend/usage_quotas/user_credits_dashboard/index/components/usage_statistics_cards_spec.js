import { GlCard } from '@gitlab/ui';
import timezoneMock from 'timezone-mock';
import UsageStatisticsCards from 'ee/usage_quotas/user_credits_dashboard/index/components/usage_statistics_cards.vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';

const GlCardStub = {
  template: '<div><slot name="header" /><slot /></div>',
};

describe('UsageStatisticsCards', () => {
  /** @type {import('helpers/vue_test_utils_helper').ExtendedWrapper} */
  let wrapper;

  const defaultProps = {
    totalUsedCredits: 42.5,
    dailyAverage: 3.2,
    peakDayUsage: 9.1,
    peakDayDate: '2026-07-15',
  };

  const createComponent = ({ props = {} } = {}) => {
    wrapper = shallowMountExtended(UsageStatisticsCards, {
      propsData: { ...defaultProps, ...props },
      stubs: { GlCard: GlCardStub },
    });
  };

  const findTotalUsageCard = () => wrapper.findByTestId('range-total-usage-card');
  const findDailyAverageCard = () => wrapper.findByTestId('daily-average-card');
  const findPeakDayUsageCard = () => wrapper.findByTestId('peak-day-usage-card');
  const findAllCards = () => wrapper.findAllComponents(GlCard);

  describe.each(['Australia/Adelaide', 'Europe/London', 'US/Pacific'])(
    '%s timezone',
    (timezone) => {
      beforeAll(() => timezoneMock.register(timezone));
      afterAll(() => timezoneMock.unregister());

      beforeEach(() => {
        createComponent();
      });

      it('renders exactly three cards', () => {
        expect(findAllCards()).toHaveLength(3);
      });

      it('renders the total usage card with the formatted value', () => {
        expect(findTotalUsageCard().text()).toContain('42.50');
        expect(findTotalUsageCard().text()).toContain('Total usage');
        expect(findTotalUsageCard().text()).toContain('in selected date range');
      });

      it('renders the daily average card with the formatted value', () => {
        expect(findDailyAverageCard().text()).toContain('3.20');
        expect(findDailyAverageCard().text()).toContain('Daily average');
        expect(findDailyAverageCard().text()).toContain('Credits per day');
      });

      it('renders the peak day usage card with the formatted value and date', () => {
        expect(findPeakDayUsageCard().text()).toContain('9.10');
        expect(findPeakDayUsageCard().text()).toContain('Peak day usage');
        expect(findPeakDayUsageCard().text()).toContain('Jul 15');
      });

      describe('when there is no peak day', () => {
        beforeEach(() => {
          createComponent({ props: { peakDayUsage: 0, peakDayDate: '' } });
        });

        it('renders zero without a date', () => {
          expect(findPeakDayUsageCard().text()).toContain('0');
          expect(findPeakDayUsageCard().text()).not.toContain('Jul');
        });

        it('renders an em dash as a fallback', () => {
          expect(findPeakDayUsageCard().text()).toContain('—');
        });
      });
    },
  );
});
