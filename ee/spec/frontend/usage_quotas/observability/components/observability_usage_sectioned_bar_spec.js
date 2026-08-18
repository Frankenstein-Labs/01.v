import { GlSprintf } from '@gitlab/ui';
import SectionedPercentageBar from '~/usage_quotas/components/sectioned_percentage_bar.vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import ObservabilityUsageSectionedBar from 'ee/usage_quotas/observability/components/observability_usage_sectioned_bar.vue';
import NumberToHumanSize from '~/vue_shared/components/number_to_human_size/number_to_human_size.vue';
import { mockStorageData } from './mock_data';

describe('ObservabilityUsageChart', () => {
  const mockUsageData = {
    ...mockStorageData,
  };

  let wrapper;

  const mountComponent = (usageData = mockUsageData) => {
    wrapper = shallowMountExtended(ObservabilityUsageSectionedBar, {
      propsData: {
        usageData,
      },
      stubs: {
        NumberToHumanSize,
        GlSprintf,
      },
    });
  };

  beforeEach(() => {
    mountComponent();
  });

  const findSectionedPercentageBar = () => wrapper.findComponent(SectionedPercentageBar);

  describe('if data_unit is bytes', () => {
    it('renders a SectionedPercentageBar component formatting values to human size', () => {
      expect(findSectionedPercentageBar().props('sections')).toEqual([
        { formattedValue: '941.13 MiB', id: 'logs', label: 'logs', value: 986845920 },
        { formattedValue: '1.17 GiB', id: 'metrics', label: 'metrics', value: 1251314399 },
        { formattedValue: '32.06 GiB', id: 'traces', label: 'traces', value: 34428565748 },
      ]);
    });

    it('renders the total usage to human size if data_unit is bytes', () => {
      expect(wrapper.text()).toBe('34.15 GiB');
    });
  });

  describe('if data_unit is not bytes', () => {
    beforeEach(() => {
      mountComponent({ ...mockUsageData, data_unit: '' });
    });
    it('renders a SectionedPercentageBar component formatting values to human size', () => {
      expect(findSectionedPercentageBar().props('sections')).toEqual([
        { formattedValue: '986.8M', id: 'logs', label: 'logs', value: 986845920 },
        { formattedValue: '1251.3M', id: 'metrics', label: 'metrics', value: 1251314399 },
        { formattedValue: '34428.6M', id: 'traces', label: 'traces', value: 34428565748 },
      ]);
    });

    it('renders the total usage to human size if data_unit is bytes', () => {
      expect(wrapper.text()).toBe('36666.7M events');
    });
  });
});
