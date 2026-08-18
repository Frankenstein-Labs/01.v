import { GlSkeletonLoader } from '@gitlab/ui';
import { shallowMount } from '@vue/test-utils';
import CatalogSkeleton from 'ee/policy_store/components/editor/catalog_skeleton.vue';

describe('CatalogSkeleton', () => {
  it('renders three rounded placeholder rows shaped like catalog options', () => {
    const wrapper = shallowMount(CatalogSkeleton);
    const rects = wrapper.findAll('rect');

    expect(wrapper.findComponent(GlSkeletonLoader).exists()).toBe(true);
    expect(rects).toHaveLength(3);
    rects.wrappers.forEach((rect) => {
      expect(rect.attributes('rx')).toBe('8');
    });
  });
});
