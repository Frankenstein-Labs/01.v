import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import AiCatalogListSkeleton from 'ee/ai/catalog/components/ai_catalog_list_skeleton.vue';

describe('AiCatalogListSkeleton', () => {
  let wrapper;

  const createComponent = (props = {}) => {
    wrapper = shallowMountExtended(AiCatalogListSkeleton, {
      propsData: { showRightElement: false, ...props },
    });
  };

  const findSkeleton = () => wrapper.findComponent(AiCatalogListSkeleton);
  const findRightElement = () => wrapper.findByTestId('right-element-placeholder');

  describe('skeleton loader component', () => {
    describe('default', () => {
      beforeEach(() => {
        createComponent();
      });

      it('renders properly', () => {
        expect(findSkeleton().exists()).toBe(true);
      });

      it('does not render the right-hand component placeholder', () => {
        expect(findRightElement().exists()).toBe(false);
      });
    });

    it('renders the right-hand component placeholder', () => {
      createComponent({ showRightElement: true });

      expect(findRightElement().exists()).toBe(true);
    });
  });
});
