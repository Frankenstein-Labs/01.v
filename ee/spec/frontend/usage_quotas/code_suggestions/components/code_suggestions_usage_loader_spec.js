import { GlSkeletonLoader } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import CodeSuggestionsUsageLoader from 'ee/usage_quotas/code_suggestions/components/code_suggestions_usage_loader.vue';

describe('Code Suggestions Usage Loader', () => {
  let wrapper;

  const findAllGlSkeletonLoaders = () => wrapper.findAllComponents(GlSkeletonLoader);

  const createComponent = () => {
    wrapper = shallowMountExtended(CodeSuggestionsUsageLoader);
  };

  describe('template', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders 3 skeleton loader components', () => {
      expect(findAllGlSkeletonLoaders()).toHaveLength(3);
    });
  });
});
