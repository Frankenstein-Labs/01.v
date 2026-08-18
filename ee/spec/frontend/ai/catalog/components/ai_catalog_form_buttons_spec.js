import { shallowMount } from '@vue/test-utils';
import { GlButton } from '@gitlab/ui';
import AiCatalogFormButtons from 'ee/ai/catalog/components/ai_catalog_form_buttons.vue';

describe('AiCatalogFormButtons', () => {
  let wrapper;

  const findButton = () => wrapper.findComponent(GlButton);

  const defaultProps = {
    isDisabled: true,
    cancelRoute: { name: 'ai-catalog-index' },
  };

  const createWrapper = (props = {}) => {
    wrapper = shallowMount(AiCatalogFormButtons, {
      propsData: {
        ...defaultProps,
        ...props,
      },
    });
  };

  describe('component rendering', () => {
    beforeEach(() => {
      createWrapper();
    });

    it('renders Cancel button with correct props', () => {
      expect(findButton().props()).toMatchObject({
        disabled: true,
        to: { name: 'ai-catalog-index' },
        type: 'button',
        category: 'secondary',
      });
    });
  });
});
