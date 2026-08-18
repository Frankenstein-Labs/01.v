import timezoneMock from 'timezone-mock';
import { GlAreaChart } from '@gitlab/ui/src/charts';
import { groupUsageDataByYear } from 'ee/usage_quotas/pipelines/namespace/utils';
import MinutesUsagePerMonth from 'ee/usage_quotas/pipelines/namespace/components/minutes_usage_per_month_chart.vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { mockGetNamespaceCiMinutesUsage } from '../mock_data';

const {
  data: { ciMinutesUsage },
} = mockGetNamespaceCiMinutesUsage;
const usageDataByYear = groupUsageDataByYear(ciMinutesUsage.nodes);

describe('MinutesUsagePerMonth', () => {
  /** @type {import('helpers/vue_test_utils_helper').ExtendedWrapper} */
  let wrapper;

  const findAreaChart = () => wrapper.findComponent(GlAreaChart);

  const createComponent = () => {
    wrapper = shallowMountExtended(MinutesUsagePerMonth, {
      propsData: {
        usageDataByYear,
        selectedYear: 2022,
      },
    });
  };

  beforeEach(() => {
    createComponent();
  });

  it('renders an area chart component', () => {
    expect(findAreaChart().exists()).toBe(true);
  });

  it('should contain a responsive attribute for the area chart', () => {
    expect(findAreaChart().attributes('responsive')).toBeDefined();
  });

  describe.each`
    timezone
    ${'Europe/London'}
    ${'US/Pacific'}
  `('when viewing in timezone', ({ timezone }) => {
    describe(timezone, () => {
      beforeEach(() => {
        createComponent();
        timezoneMock.register(timezone);
      });

      afterEach(() => {
        timezoneMock.unregister();
      });

      it('has the right start month', () => {
        expect(findAreaChart().props('data')[0].data[0][0]).toEqual('Jun 2022');
      });
    });
  });
});
