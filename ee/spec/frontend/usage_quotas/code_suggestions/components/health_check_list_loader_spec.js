import { GlSkeletonLoader } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import HealthCheckListLoader from 'ee/usage_quotas/code_suggestions/components/health_check_list_loader.vue';

describe('Health Check List Loader', () => {
  let wrapper;

  const findAllGlSkeletonLoaders = () => wrapper.findAllComponents(GlSkeletonLoader);

  const createComponent = () => {
    wrapper = shallowMountExtended(HealthCheckListLoader);
  };

  describe('template', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders 1 skeleton loader component', () => {
      expect(findAllGlSkeletonLoaders()).toHaveLength(1);
    });
  });
});
