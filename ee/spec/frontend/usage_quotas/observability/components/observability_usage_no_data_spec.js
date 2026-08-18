import { GlEmptyState } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import ObservabilityUsageNoData from 'ee/usage_quotas/observability/components/observability_usage_no_data.vue';

describe('ObservabilityUsageNoData', () => {
  let wrapper;

  beforeEach(() => {
    wrapper = shallowMountExtended(ObservabilityUsageNoData);
  });

  const findEmptyState = () => wrapper.findComponent(GlEmptyState);

  it('passes the correct title prop to GlEmptyState', () => {
    expect(findEmptyState().props('title')).toBe(
      'Sorry, there is no usage data for the selected period',
    );
  });

  it('renders the description slot with the correct content', () => {
    expect(findEmptyState().text()).toBe('Try selecting a different period.');
  });
});
