import { GlStackedColumnChart } from '@gitlab/ui/src/charts';
import { GlButton, GlSprintf } from '@gitlab/ui';
import CreditsConsumptionChart from 'ee/usage_quotas/wallet_agnostic_credits_dashboard/index/components/credits_consumption_chart.vue';
import { shallowMountExtended, getInstanceSlots } from 'helpers/vue_test_utils_helper';
import { getSlotText } from 'ee_jest/usage_quotas/usage_billing/components/__helpers__/get_slot_text';
import { mockSubscriptionCreditsUsageData } from '../../mock_data';

describe('CreditsConsumptionChart', () => {
  /** @type {import('helpers/vue_test_utils_helper').ExtendedWrapper} */
  let wrapper;

  const createComponent = (propsData = {}) => {
    wrapper = shallowMountExtended(CreditsConsumptionChart, {
      propsData: {
        startDate: mockSubscriptionCreditsUsageData.data.subscriptionUsage.startDate,
        endDate: mockSubscriptionCreditsUsageData.data.subscriptionUsage.endDate,
        dailyUsage: mockSubscriptionCreditsUsageData.data.subscriptionUsage.dailyUsage,
        totalCredits: mockSubscriptionCreditsUsageData.data.subscriptionUsage.creditsUsed,
        ...propsData,
      },
      stubs: {
        GlButton,
        GlSprintf,
      },
    });
  };

  const findChart = () => wrapper.findComponent(GlStackedColumnChart);

  beforeEach(() => {
    createComponent();
  });

  it('renders the stacked column chart', () => {
    expect(findChart().exists()).toBe(true);
  });

  it('renders the total credits', () => {
    expect(wrapper.text()).toContain('13.8k');
  });

  describe('date range calculation', () => {
    it('generates all dates in the billing period for groupBy', () => {
      createComponent({
        startDate: '2026-02-01',
        endDate: '2026-02-05',
        dailyUsage: [{ creditsUsed: 100, date: '2026-02-03' }],
      });

      expect(findChart().props('groupBy')).toEqual([
        '2026-02-01',
        '2026-02-02',
        '2026-02-03',
        '2026-02-04',
        '2026-02-05',
      ]);
    });
  });

  describe('data series rendering', () => {
    describe('data array building', () => {
      it('fills missing dates with null values', () => {
        createComponent({
          startDate: '2026-02-01',
          endDate: '2026-02-05',
          dailyUsage: [
            { creditsUsed: 100, date: '2026-02-01' },
            { creditsUsed: 200, date: '2026-02-03' },
            { creditsUsed: 300, date: '2026-02-05' },
          ],
        });

        const dailyData = findChart().props('bars')[0].data;

        expect(dailyData).toEqual([
          ['2026-02-01', 100],
          ['2026-02-02', null],
          ['2026-02-03', 200],
          ['2026-02-04', null],
          ['2026-02-05', 300],
        ]);
      });
    });
  });

  describe('x-axis label formatter', () => {
    it('formats ISO date strings as short month and day', () => {
      const { formatter } = findChart().props('option').xAxis.axisLabel;

      expect(formatter('2026-02-03')).toBe('Feb 3');
    });
  });

  describe('tooltip-value slot', () => {
    let slotFn;

    beforeEach(() => {
      slotFn = getInstanceSlots(wrapper.findComponent(GlStackedColumnChart).vm)['tooltip-value'];
    });

    it('formats a regular number', () => {
      const slotContent = slotFn({ value: [null, 1000] });

      expect(getSlotText(slotContent)).toContain('1k');
    });

    it('formats zero as a visible value', () => {
      const slotContent = slotFn({ value: [null, 0] });

      expect(getSlotText(slotContent)).toContain('0');
    });

    it('renders a dash for null values', () => {
      const slotContent = slotFn({ value: [null, null] });

      expect(getSlotText(slotContent)).toContain('—');
    });
  });
});
