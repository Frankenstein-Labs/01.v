import { GlProgressBar, GlSprintf } from '@gitlab/ui';
import CurrentUsageCard from 'ee/usage_quotas/usage_billing/components/current_usage_card.vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { useFakeDate } from 'helpers/fake_date';

describe('CurrentUsageCard', () => {
  /** @type {import('helpers/vue_test_utils_helper').ExtendedWrapper} */
  let wrapper;

  const defaultProps = {
    poolCreditsUsed: 7800,
    poolTotalCredits: 10000,
    monthEndDate: '2025-10-31',
  };

  // '2025-10-10'
  useFakeDate(2025, 9, 10);

  const createComponent = (props) => {
    wrapper = shallowMountExtended(CurrentUsageCard, {
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
      expect(wrapper.find('h2').text()).toBe('Monthly Committed Pool');
    });

    it('renders formatted total credits used', () => {
      expect(wrapper.findByTestId('total-credits-used').text()).toBe('7.8k');
    });

    it('renders formatted total credits', () => {
      expect(wrapper.findByTestId('pool-total-credits').text()).toMatchInterpolatedText('/ 10k');
    });

    it('renders the subtitle with month info', () => {
      const subtitle = wrapper.findByTestId('monthly-commitment-subtitle');

      expect(subtitle.text()).toMatchInterpolatedText('Credits used this month, resets in 21 days');
    });
  });

  describe('gl-progress-bar', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders gl-progress-bar with correct credits', () => {
      const progressBar = wrapper.findComponent(GlProgressBar);

      expect(progressBar.props('value')).toBe(78);
      expect(progressBar.props('max')).toBe(100);
      expect(progressBar.props('variant')).toBe('primary');
    });
  });

  describe('rendering credits percentages', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders correct utilized credits percentage', () => {
      expect(wrapper.findByTestId('percentage-utilized').text()).toBe('78% of credits used');
    });

    it('renders correct credits remaining', () => {
      expect(wrapper.findByTestId('pool-credits-remaining').text()).toBe('2.2k credits remaining');
    });

    it('renders shared pool description', () => {
      expect(wrapper.text()).toContain(
        'Shared pool of credits available to all users in the subscription.',
      );
    });
  });

  describe('when total credits is 0', () => {
    beforeEach(() => {
      createComponent({ poolTotalCredits: 0 });
    });

    it('renders correct utilized credits percentage', () => {
      expect(wrapper.findByTestId('percentage-utilized').text()).toBe('0% of credits used');
    });

    it('passes 0 as gl-progress-bar value', () => {
      expect(wrapper.findComponent(GlProgressBar).props('value')).toBe(0);
    });
  });
});
