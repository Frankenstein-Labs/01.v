import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import UsageCards from 'ee/usage_quotas/wallet_agnostic_credits_dashboard/index/components/usage_cards.vue';

describe('UsageCards', () => {
  /** @type {import('@vue/test-utils').Wrapper<Vue>} */
  let wrapper;

  const defaultProps = {
    totalUsedCredits: 1234567,
    activeUsersCount: 1542,
    dailyAverage: 50012,
    peakDayUsage: 15000,
    peakDayDate: '2026-03-26',
  };

  const createComponent = (props = {}) => {
    wrapper = shallowMountExtended(UsageCards, {
      propsData: {
        ...defaultProps,
        ...props,
      },
    });
  };

  const findTotalUsageCard = () => wrapper.findByTestId('total-usage-card');
  const findActiveUsersCard = () => wrapper.findByTestId('active-users-card');
  const findDailyAverageCard = () => wrapper.findByTestId('daily-average-card');
  const findPeakDayUsageCard = () => wrapper.findByTestId('peak-day-usage-card');

  beforeEach(() => {
    createComponent();
  });

  it('renders total usage card', () => {
    expect(findTotalUsageCard().text()).toMatchInterpolatedText(
      'Total usage 1.2m in selected date range',
    );
  });

  it('renders active users card', () => {
    expect(findActiveUsersCard().text()).toMatchInterpolatedText(
      'Active users 1.5k in selected date range',
    );
  });

  it('renders daily average card', () => {
    expect(findDailyAverageCard().text()).toMatchInterpolatedText(
      'Daily average 50k Credits per day',
    );
  });

  describe('peak day usage card', () => {
    it('renders peak day usage card', () => {
      createComponent();
      expect(findPeakDayUsageCard().text()).toMatchInterpolatedText('Peak day usage 15k Mar 26');
    });

    it('renders 0 for usage value when peakDayUsage is missing', () => {
      createComponent({ peakDayUsage: undefined });
      expect(findPeakDayUsageCard().text()).toMatchInterpolatedText('Peak day usage 0 Mar 26');
    });

    it('renders the usage without the date when peak day date is missing', () => {
      createComponent({ peakDayDate: null });
      expect(findPeakDayUsageCard().text()).toMatchInterpolatedText('Peak day usage 15k');
    });
  });
});
