import { GlDisclosureDropdown, GlToggle } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import PromptInputActions from 'ee/ai/duo_agentic_chat/components/prompt_input_actions.vue';

describe('PromptInputActions', () => {
  let wrapper;

  const createComponent = ({ propsData = {}, glFeatures = {} } = {}) => {
    wrapper = shallowMountExtended(PromptInputActions, {
      propsData,
      provide: { glFeatures },
    });
  };

  const findDropdown = () => wrapper.findComponent(GlDisclosureDropdown);
  const findWebSearchToggle = () => wrapper.findComponent(GlToggle);
  const findWebSearchItem = () => wrapper.findComponentByTestId('web-search-item');

  const webSearchOn = { dapWebSearch: true };

  describe('visibility', () => {
    it('renders nothing when web search is disabled', () => {
      createComponent({ glFeatures: { dapWebSearch: false } });

      expect(findDropdown().exists()).toBe(false);
    });

    it('renders the dropdown when web search is enabled', () => {
      createComponent({ glFeatures: webSearchOn });

      expect(findDropdown().exists()).toBe(true);
    });

    it('renders the dropdown without a caret', () => {
      createComponent({ glFeatures: webSearchOn });

      expect(findDropdown().props('noCaret')).toBe(true);
    });
  });

  describe('web search toggle', () => {
    it.each([true, false])(
      'reflects the webSearchEnabled prop (%s) as the toggle value',
      (value) => {
        createComponent({ glFeatures: webSearchOn, propsData: { webSearchEnabled: value } });

        expect(findWebSearchToggle().props('value')).toBe(value);
      },
    );

    it('gives the toggle an accessible label', () => {
      createComponent({ glFeatures: webSearchOn });

      expect(findWebSearchToggle().props('label')).toBe('Web search');
    });

    it.each`
      webSearchEnabled | expected
      ${false}         | ${true}
      ${true}          | ${false}
    `(
      'emits update:web-search-enabled with $expected when the row is activated (current: $webSearchEnabled)',
      ({ webSearchEnabled, expected }) => {
        createComponent({ glFeatures: webSearchOn, propsData: { webSearchEnabled } });

        findWebSearchItem().vm.$emit('action');

        expect(wrapper.emitted('update:web-search-enabled')).toEqual([[expected]]);
      },
    );
  });

  describe('disabled state', () => {
    it('disables the dropdown toggle when the disabled prop is true', () => {
      createComponent({ glFeatures: webSearchOn, propsData: { disabled: true } });

      expect(findDropdown().props('disabled')).toBe(true);
    });
  });
});
