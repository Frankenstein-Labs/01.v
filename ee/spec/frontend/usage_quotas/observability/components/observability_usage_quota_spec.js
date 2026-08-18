import { GlLoadingIcon } from '@gitlab/ui';
import ObservabilityUsageQuota from 'ee/usage_quotas/observability/components/observability_usage_quota.vue';
import ObservabilityUsageBreakdown from 'ee/usage_quotas/observability/components/observability_usage_breakdown.vue';
import ObservabilityUsagePeriodSelector from 'ee/usage_quotas/observability/components/observability_usage_period_selector.vue';
import { createMockClient } from 'helpers/mock_observability_client';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { createAlert } from '~/alert';
import { useFakeDate } from 'helpers/fake_date';
import { mockData } from './mock_data';

jest.mock('~/alert');

describe('ObservabilityUsageQuota', () => {
  useFakeDate('2024-08-01');

  let wrapper;
  let observabilityClientMock;

  const mockUsageData = {
    ...mockData,
  };
  const mountComponent = async () => {
    wrapper = shallowMountExtended(ObservabilityUsageQuota, {
      propsData: {
        observabilityClient: observabilityClientMock,
      },
    });
    await waitForPromises();
  };

  const findLoadingIcon = () => wrapper.findComponent(GlLoadingIcon);
  const findUsageBreakdown = () => wrapper.findComponent(ObservabilityUsageBreakdown);
  const findPeriodSelector = () => wrapper.findComponent(ObservabilityUsagePeriodSelector);

  beforeEach(() => {
    observabilityClientMock = createMockClient();
    observabilityClientMock.fetchUsageData.mockResolvedValue(mockUsageData);
  });

  it('renders the loading indicator while fetching data', () => {
    mountComponent();

    expect(findLoadingIcon().exists()).toBe(true);
    expect(findUsageBreakdown().exists()).toBe(false);
    expect(observabilityClientMock.fetchUsageData).toHaveBeenCalledWith({
      period: {
        month: 8,
        year: 2024,
      },
    });
  });

  it('renders the usage breakdown after fetching data', async () => {
    await mountComponent();

    expect(findLoadingIcon().exists()).toBe(false);
    expect(findUsageBreakdown().exists()).toBe(true);
    expect(findUsageBreakdown().props('usageData')).toEqual(mockUsageData);
  });

  it('initially renders period selector with today date value', async () => {
    await mountComponent();

    expect(findPeriodSelector().props('value')).toEqual({ month: 7, year: 2024 });
  });

  it('fetches data with the selected period', async () => {
    await mountComponent();

    const period = { month: 6, year: 2024 };
    await findPeriodSelector().vm.$emit('input', period);

    expect(observabilityClientMock.fetchUsageData).toHaveBeenCalledWith({
      period: {
        month: period.month + 1,
        year: period.year,
      },
    });
    expect(findPeriodSelector().props('value')).toEqual(period);
  });

  it('if fetchUsageData fails, it renders an alert', async () => {
    observabilityClientMock.fetchUsageData.mockRejectedValue('error');

    await mountComponent();

    expect(createAlert).toHaveBeenLastCalledWith({
      message: 'Failed to load observability usage data.',
    });
    expect(findUsageBreakdown().exists()).toBe(false);
    expect(findLoadingIcon().exists()).toBe(false);
  });
});
