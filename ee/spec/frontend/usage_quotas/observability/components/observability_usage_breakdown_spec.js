import { GlSprintf } from '@gitlab/ui';
import ObservabilityUsageBreakdown from 'ee/usage_quotas/observability/components/observability_usage_breakdown.vue';
import ObservabilityUsageSectionedBar from 'ee/usage_quotas/observability/components/observability_usage_sectioned_bar.vue';
import ObservabilityUsageChart from 'ee/usage_quotas/observability/components/observability_usage_chart.vue';
import ObservabilityUsageNoData from 'ee/usage_quotas/observability/components/observability_usage_no_data.vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import NumberToHumanSize from '~/vue_shared/components/number_to_human_size/number_to_human_size.vue';
import { mockData, mockEventsData, mockStorageData } from './mock_data';

describe('ObservabilityUsageBreakdown', () => {
  let wrapper;

  const mountComponent = (usageData = mockData) => {
    wrapper = shallowMountExtended(ObservabilityUsageBreakdown, {
      propsData: {
        usageData,
      },
      stubs: {
        GlSprintf,
        NumberToHumanSize,
      },
    });
  };

  beforeEach(() => {
    mountComponent();
  });

  const findSectionedStorageUsage = () => wrapper.findComponentByTestId('sectioned-storage-usage');
  const findSectionedEventsUsage = () => wrapper.findComponentByTestId('sectioned-events-usage');
  const findStorageUsageChart = () => wrapper.findComponentByTestId('storage-usage-chart');
  const findEventsUsageChart = () => wrapper.findComponentByTestId('events-usage-chart');
  const findNoDataComponent = () => wrapper.findComponent(ObservabilityUsageNoData);

  it('renders a title and subtitle', () => {
    expect(wrapper.find('h3').text()).toBe('Usage breakdown');
    expect(wrapper.find('p').text()).toBe('Includes Logs, Traces and Metrics. Learn more.');
  });

  it('renders ObservabilityUsageSectionedBar', () => {
    expect(wrapper.findAllComponents(ObservabilityUsageSectionedBar)).toHaveLength(2);
  });

  it('renders the sectioned storage usage', () => {
    expect(findSectionedStorageUsage().props('usageData')).toEqual(mockStorageData);
  });

  it('renders the sectioned events usage', () => {
    expect(findSectionedEventsUsage().props('usageData')).toEqual(mockEventsData);
  });

  it('renders ObservabilityUsageChart', () => {
    expect(wrapper.findAllComponents(ObservabilityUsageChart)).toHaveLength(2);
  });

  it('renders storage usage chart', () => {
    expect(findStorageUsageChart().props('usageData')).toEqual(mockStorageData);
  });

  it('renders events usage chart', () => {
    expect(findEventsUsageChart().props('usageData')).toEqual(mockEventsData);
  });

  describe('if events data is missing', () => {
    beforeEach(() => {
      mountComponent({ ...mockData, events: {} });
    });

    it('does not render SectionedEventsUsage', () => {
      expect(findSectionedEventsUsage().exists()).toBe(false);
    });

    it('does not render EventsUsageChart', () => {
      expect(findEventsUsageChart().exists()).toBe(false);
    });

    it('does not render the no data component', () => {
      expect(findNoDataComponent().exists()).toBe(false);
    });
  });

  describe('if storage data is missing', () => {
    beforeEach(() => {
      mountComponent({ ...mockData, storage: {} });
    });

    it('does not render SectionedStorageUsage', () => {
      expect(findSectionedStorageUsage().exists()).toBe(false);
    });

    it('does not render EventsUsageChart', () => {
      expect(findStorageUsageChart().exists()).toBe(false);
    });

    it('does not render the no data component', () => {
      expect(findNoDataComponent().exists()).toBe(false);
    });
  });

  it('renders the no data component, if events and storage data are missing', () => {
    mountComponent({ storage: {}, events: {} });
    expect(findNoDataComponent().exists()).toBe(true);
  });
});
