import ObservabilityUsageQuotaApp from 'ee/usage_quotas/observability/components/observability_usage_quota_app.vue';
import ObservabilityUsageQuota from 'ee/usage_quotas/observability/components/observability_usage_quota.vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import * as observabilityClient from '~/observability/client';
import { createMockClient, mockApiConfig } from 'helpers/mock_observability_client';

describe('ObservabilityUsageQuotaApp', () => {
  let wrapper;

  const observabilityClientMock = createMockClient();

  const mountComponent = () => {
    wrapper = shallowMountExtended(ObservabilityUsageQuotaApp, {
      provide: {
        apiConfig: { ...mockApiConfig },
      },
    });
  };

  beforeEach(() => {
    jest.spyOn(observabilityClient, 'buildClient').mockReturnValue(observabilityClientMock);

    mountComponent();
  });

  it('renders the ObservabilityUsageQuota', () => {
    expect(wrapper.findComponent(ObservabilityUsageQuota).exists()).toBe(true);
  });

  it('builds the observability client', () => {
    expect(observabilityClient.buildClient).toHaveBeenCalledWith(mockApiConfig);
  });
});
