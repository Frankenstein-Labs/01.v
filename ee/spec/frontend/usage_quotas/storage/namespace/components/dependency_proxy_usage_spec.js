import { shallowMount } from '@vue/test-utils';
import DependencyProxyUsage from 'ee/usage_quotas/storage/namespace/components/dependency_proxy_usage.vue';
import CeDependencyProxyUsage from '~/usage_quotas/storage/namespace/components/dependency_proxy_usage.vue';

describe('Dependency proxy usage component', () => {
  let wrapper;

  const createComponent = (options = {}) => {
    const defaults = {
      dependencyProxyTotalSize: 512,
    };

    return shallowMount(DependencyProxyUsage, {
      propsData: {
        ...defaults,
        ...options,
      },
    });
  };
  const findCeComponent = () => wrapper.findComponent(CeDependencyProxyUsage);

  beforeEach(() => {
    wrapper = createComponent();
  });

  it('should pass the correct description to the ce component', () => {
    expect(findCeComponent().props('description')).toBe(
      'Cache for frequently-accessed Docker images and virtual registries.',
    );
  });
});
