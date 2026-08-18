import { GlSprintf } from '@gitlab/ui';
import MonthlyWaiverCard from 'ee/usage_quotas/usage_billing/components/monthly_waiver_card.vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';

describe('MonthlyWaiverCard', () => {
  /** @type {import('helpers/vue_test_utils_helper').ExtendedWrapper} */
  let wrapper;

  const defaultProps = {
    monthlyWaiverTotalCredits: 100_200.32,
    monthlyWaiverCreditsUsed: 1300.75,
  };

  const createComponent = (props) => {
    wrapper = shallowMountExtended(MonthlyWaiverCard, {
      propsData: {
        ...defaultProps,
        ...props,
      },
      stubs: {
        GlSprintf,
      },
    });
  };

  describe('rendering elements', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders card title', () => {
      expect(wrapper.find('h2').text()).toBe('Monthly Waiver');
    });

    it('renders monthly waiver credits used', () => {
      expect(wrapper.findByTestId('monthly-waiver-credits-used').text()).toBe('1.3k');
    });

    it('renders remaining credits', () => {
      expect(wrapper.findByTestId('monthly-waiver-remaining-credits').text()).toBe('98.9k');
    });

    describe('edge cases', () => {
      describe('with zero credits', () => {
        beforeEach(() => {
          createComponent({
            monthlyWaiverTotalCredits: 0,
            monthlyWaiverCreditsUsed: 0,
          });
        });

        it('renders zero for credits used', () => {
          expect(wrapper.findByTestId('monthly-waiver-credits-used').text()).toBe('0');
        });

        it('renders zero for remaining credits', () => {
          expect(wrapper.findByTestId('monthly-waiver-remaining-credits').text()).toBe('0');
        });
      });

      describe('with credits used exceeding total (over-usage)', () => {
        beforeEach(() => {
          createComponent({
            monthlyWaiverTotalCredits: 100,
            monthlyWaiverCreditsUsed: 200,
          });
        });

        it('renders credits used', () => {
          expect(wrapper.findByTestId('monthly-waiver-credits-used').text()).toBe('200');
        });

        it('renders negative remaining credits', () => {
          expect(wrapper.findByTestId('monthly-waiver-remaining-credits').text()).toBe('-100');
        });
      });

      describe('with small decimal values', () => {
        beforeEach(() => {
          createComponent({
            monthlyWaiverTotalCredits: 10.5,
            monthlyWaiverCreditsUsed: 3.25,
          });
        });

        it('renders credits used with decimal precision', () => {
          expect(wrapper.findByTestId('monthly-waiver-credits-used').text()).toBe('3.25');
        });

        it('renders remaining credits with decimal precision', () => {
          expect(wrapper.findByTestId('monthly-waiver-remaining-credits').text()).toBe('7.25');
        });
      });
    });
  });
});
