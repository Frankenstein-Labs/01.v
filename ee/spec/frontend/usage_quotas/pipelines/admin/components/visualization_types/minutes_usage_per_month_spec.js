import { GlAreaChart } from '@gitlab/ui/src/charts';
import MinutesUsagePerMonth from 'ee/usage_quotas/pipelines/admin/components/visualization_types/minutes_usage_per_month.vue';
import NoMinutesAlert from 'ee/usage_quotas/pipelines/admin/components/shared/no_minutes_alert.vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { usageDataInstanceAggregated } from '../../mock_data';

describe('MinutesUsagePerMonth', () => {
  /** @type {import('helpers/vue_test_utils_helper').ExtendedWrapper} */
  let wrapper;

  const findAreaChart = () => wrapper.findComponent(GlAreaChart);
  const findNoMinutesAlertComponent = () => wrapper.findComponent(NoMinutesAlert);

  const createComponent = (props = {}) => {
    wrapper = shallowMountExtended(MinutesUsagePerMonth, {
      propsData: {
        usageData: usageDataInstanceAggregated,
        isLoading: false,
        ...props,
      },
    });
  };

  describe('with usage data', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders an area chart component', () => {
      expect(findAreaChart().exists()).toBe(true);
    });

    it('should contain a responsive attribute for the area chart', () => {
      expect(findAreaChart().attributes('responsive')).toBeDefined();
    });
  });

  describe('without usage data', () => {
    beforeEach(() => {
      createComponent({
        usageData: [],
      });
    });

    it('renders an empty state', () => {
      expect(findNoMinutesAlertComponent().exists()).toBe(true);
    });
  });
});
