import MonthlyUnitsUsageSummary from 'ee/usage_quotas/pipelines/namespace/components/cards/monthly_units_usage_summary.vue';
import StatisticsCard from 'ee/usage_quotas/components/statistics_card.vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { localeDateFormat, newDate } from '~/lib/utils/datetime_utility';
import { defaultProvide } from '../../mock_data';

describe('MonthlyUnitsUsageSummary', () => {
  /** @type {import('helpers/vue_test_utils_helper').ExtendedWrapper} */
  let wrapper;

  const defaultProps = {
    monthlyUnitsUsed: defaultProvide.ciMinutesMonthlyMinutesUsed,
    monthlyUnitsLimit: defaultProvide.ciMinutesMonthlyMinutesLimit,
    monthlyUnitsUsedPercentage: defaultProvide.ciMinutesMonthlyMinutesUsedPercentage,
    lastResetDate: defaultProvide.ciMinutesLastResetDate,
    anyProjectEnabled: defaultProvide.ciMinutesAnyProjectEnabled,
    displayMinutesAvailableData: defaultProvide.ciMinutesDisplayMinutesAvailableData,
  };

  const createComponent = ({ props = {} } = {}) => {
    wrapper = shallowMountExtended(MonthlyUnitsUsageSummary, {
      propsData: {
        ...defaultProps,
        ...props,
      },
    });
  };

  const findStatisticsCard = () => wrapper.findComponent(StatisticsCard);

  beforeEach(() => {
    createComponent();
  });

  it('passes props to StatisticsCard', () => {
    expect(findStatisticsCard().props()).toEqual(
      expect.objectContaining({
        usageValue: defaultProps.monthlyUnitsUsed,
        totalValue: defaultProps.monthlyUnitsLimit,
        totalUnit: 'compute minutes',
        percentage: defaultProps.monthlyUnitsUsedPercentage,
      }),
    );
  });

  it('displays last reset date', () => {
    expect(findStatisticsCard().props('description')).toBe(
      `Compute usage since ${localeDateFormat.asDate.format(newDate(defaultProps.lastResetDate))}`,
    );
  });

  describe('Unlimited', () => {
    beforeEach(() => {
      createComponent({
        props: {
          monthlyUnitsLimit: 'Unlimited',
          monthlyUnitsUsedPercentage: 0,
          displayMinutesAvailableData: false,
        },
      });
    });

    it('passes props to StatisticsCard', () => {
      expect(findStatisticsCard().props()).toEqual(
        expect.objectContaining({
          usageValue: defaultProps.monthlyUnitsUsed,
          totalValue: 'Unlimited',
          totalUnit: 'compute minutes',
          percentage: null,
        }),
      );
    });
  });

  describe('Unsupported', () => {
    beforeEach(() => {
      createComponent({
        props: {
          monthlyUnitsLimit: 'Not supported',
          monthlyUnitsUsedPercentage: 0,
          anyProjectEnabled: false,
          displayMinutesAvailableData: false,
        },
      });
    });

    it('passes props to StatisticsCard', () => {
      expect(findStatisticsCard().props()).toEqual(
        expect.objectContaining({
          usageValue: defaultProps.monthlyUnitsUsed,
          usageUnit: 'compute minutes',
          totalValue: 'Not supported',
          percentage: null,
        }),
      );
    });
  });
});
