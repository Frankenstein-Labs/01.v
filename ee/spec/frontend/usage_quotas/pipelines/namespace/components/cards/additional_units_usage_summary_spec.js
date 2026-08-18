import AdditionalUnitsUsageSummary from 'ee/usage_quotas/pipelines/namespace/components/cards/additional_units_usage_summary.vue';
import StatisticsCard from 'ee/usage_quotas/components/statistics_card.vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { defaultProvide } from '../../mock_data';

describe('AdditionalUnitsUsageSummary', () => {
  /** @type {import('helpers/vue_test_utils_helper').ExtendedWrapper} */
  let wrapper;

  const defaultProps = {
    additionalUnitsUsed: defaultProvide.ciMinutesPurchasedMinutesUsed,
    additionalUnitsLimit: defaultProvide.ciMinutesPurchasedMinutesLimit,
    additionalUnitsUsedPercentage: defaultProvide.ciMinutesPurchasedMinutesUsedPercentage,
  };

  const createComponent = ({ props = {} } = {}) => {
    wrapper = shallowMountExtended(AdditionalUnitsUsageSummary, {
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

  it('passes props to the StatisticsCard', () => {
    expect(findStatisticsCard().props()).toEqual(
      expect.objectContaining({
        usageValue: defaultProps.additionalUnitsUsed,
        totalValue: defaultProps.additionalUnitsLimit,
        totalUnit: 'compute minutes',
        percentage: Number(defaultProps.additionalUnitsUsedPercentage),
      }),
    );
  });
});
