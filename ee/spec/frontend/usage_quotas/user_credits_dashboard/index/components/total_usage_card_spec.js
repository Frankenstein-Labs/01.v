import { GlCard } from '@gitlab/ui';
import TotalUsageCard from 'ee/usage_quotas/user_credits_dashboard/index/components/total_usage_card.vue';
import HumanTimeframe from '~/vue_shared/components/datetime/human_timeframe.vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';

describe('TotalUsageCard', () => {
  /** @type {import('helpers/vue_test_utils_helper').ExtendedWrapper} */
  let wrapper;

  const defaultProps = {
    creditsUsed: 12.5,
    startDate: '2026-07-01',
    endDate: '2026-07-31',
  };

  const createComponent = ({ props = {} } = {}) => {
    wrapper = shallowMountExtended(TotalUsageCard, {
      propsData: { ...defaultProps, ...props },
    });
  };

  const findCard = () => wrapper.findComponent(GlCard);
  const findCredits = () => wrapper.findByTestId('billing-period-credits');
  const findTimeframe = () => wrapper.findComponent(HumanTimeframe);

  it('renders a card with the formatted credits used', () => {
    createComponent();

    expect(findCard().exists()).toBe(true);
    expect(findCredits().text()).toBe('12.50');
  });

  it('renders the billing period label', () => {
    createComponent();

    expect(wrapper.text()).toContain('Credits used in this billing period');
  });

  it('renders the timeframe from the start and end dates', () => {
    createComponent();

    expect(findTimeframe().props()).toMatchObject({
      from: defaultProps.startDate,
      till: defaultProps.endDate,
    });
  });

  it('formats a zero value', () => {
    createComponent({ props: { creditsUsed: 0 } });

    expect(findCredits().text()).toBe('0');
  });

  describe('when the timeframe is incomplete', () => {
    it.each([
      ['no start date', { startDate: null }],
      ['no end date', { endDate: null }],
    ])('does not render the timeframe with %s', (_, props) => {
      createComponent({ props });

      expect(findTimeframe().exists()).toBe(false);
    });
  });
});
