import { GlColumnChart } from '@gitlab/ui/src/charts';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import ObservabilityUsageChart from 'ee/usage_quotas/observability/components/observability_usage_chart.vue';
import { stubComponent } from 'helpers/stub_component';
import { mockStorageData } from './mock_data';

describe('ObservabilityUsageChart', () => {
  const mockUsageData = {
    ...mockStorageData,
  };

  let wrapper;

  const mountComponent = ({ mockTooltipValue = '', usageData = mockUsageData } = {}) => {
    const mockChartWithTooltip = {
      data() {
        return { tooltipValue: mockTooltipValue };
      },
      template: `<div><slot name="tooltip-value" :value="tooltipValue"></slot></div>`,
    };
    wrapper = shallowMountExtended(ObservabilityUsageChart, {
      propsData: {
        usageData,
        title: 'Usage Chart',
      },
      stubs: {
        GlColumnChart: stubComponent(GlColumnChart, mockChartWithTooltip),
      },
    });
  };

  beforeEach(() => {
    mountComponent();
  });

  const findColumnChart = () => wrapper.findComponent(GlColumnChart);

  it('computes chartData correctly', () => {
    expect(findColumnChart().props('bars')).toEqual([
      {
        data: [
          ['2024-07-07', 481626089],
          ['2024-07-08', 505219831],
        ],
        name: 'logs',
      },
      {
        data: [
          ['2024-07-07', 588125804],
          ['2024-07-08', 663188595],
        ],
        name: 'metrics',
      },
      {
        data: [
          ['2024-07-07', 17207830769],
          ['2024-07-08', 17220734979],
        ],
        name: 'traces',
      },
    ]);
  });

  it('renders the tooltip value to human size if unit is bytes', () => {
    mountComponent({ mockTooltipValue: 10000 });

    expect(findColumnChart().text()).toBe('9.77 KiB');
  });

  it('renders the tooltip value as it is if unit is not bytes', () => {
    mountComponent({ mockTooltipValue: 10000, usageData: { ...mockUsageData, data_unit: '' } });

    expect(findColumnChart().text()).toBe('10K');
  });
});
