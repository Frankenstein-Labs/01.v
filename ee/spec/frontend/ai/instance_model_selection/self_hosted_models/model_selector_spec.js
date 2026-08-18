import { shallowMount } from '@vue/test-utils';
import ModelSelector from 'ee/ai/instance_model_selection/self_hosted_models/components/model_selector.vue';
import ModelSelectDropdown from 'ee/ai/shared/feature_settings/model_select_dropdown.vue';
import { RELEASE_STATES } from 'ee/ai/instance_model_selection/constants';
import { SELF_HOSTED_MODEL_OPTIONS } from './mock_data';

describe('ModelSelector', () => {
  let wrapper;

  const selectedModel = 'MISTRAL';
  const createComponent = ({ props = {} } = {}) => {
    wrapper = shallowMount(ModelSelector, {
      provide: {
        modelOptions: SELF_HOSTED_MODEL_OPTIONS,
      },
      propsData: {
        selectedModel,
        isLoading: false,
        ...props,
      },
    });
  };

  beforeEach(() => {
    createComponent();
  });

  const findModelSelectDropdown = () => wrapper.findComponent(ModelSelectDropdown);

  it('renders `ModelSelectDropdown` and passes the correct props', () => {
    expect(findModelSelectDropdown().props('placeholderDropdownText')).toBe('Select model');
    expect(findModelSelectDropdown().props('isLoading')).toBe(false);
    expect(findModelSelectDropdown().props('selectedOption')).toStrictEqual({
      value: 'MISTRAL',
      text: 'Mistral',
      releaseState: 'GA',
    });
  });

  describe('.availableModels', () => {
    it('sorts models by release state (GA first, then BETA)', () => {
      const availableModels = findModelSelectDropdown().props('items');

      expect(availableModels).toStrictEqual([
        { value: 'CODESTRAL', text: 'Codestral', releaseState: RELEASE_STATES.GA },
        { value: 'MISTRAL', text: 'Mistral', releaseState: RELEASE_STATES.GA },
        { value: 'GPT', text: 'GPT', releaseState: RELEASE_STATES.GA },
        { value: 'CLAUDE_3', text: 'Claude', releaseState: RELEASE_STATES.GA },
        { value: 'CODEGEMMA', text: 'CodeGemma', releaseState: RELEASE_STATES.BETA },
        { value: 'CODELLAMA', text: 'Code-Llama', releaseState: RELEASE_STATES.BETA },
        { value: 'DEEPSEEKCODER', text: 'Deepseek Coder', releaseState: RELEASE_STATES.BETA },
        { value: 'LLAMA3', text: 'Llama 3', releaseState: RELEASE_STATES.BETA },
      ]);
    });
  });

  it('emits an update event when the model is changed', () => {
    findModelSelectDropdown().vm.$emit('select', 'MISTRAL');

    expect(wrapper.emitted('update:model')).toEqual([['MISTRAL']]);
  });
});
