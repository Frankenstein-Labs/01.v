import { nextTick } from 'vue';
import { shallowMount } from '@vue/test-utils';
import { GlFormGroup, GlFormInput, GlLink, GlSprintf } from '@gitlab/ui';
import { extendedWrapper } from 'helpers/vue_test_utils_helper';
import AiGtewayUrlInputForm from 'ee/ai/settings/components/ai_gateway_url_input_form.vue';

let wrapper;

const aiGatewayUrl = 'http://0.0.0.0:5052';
const createComponent = ({ props = {} } = {}) => {
  wrapper = extendedWrapper(
    shallowMount(AiGtewayUrlInputForm, {
      propsData: {
        value: aiGatewayUrl,
        ...props,
      },
      stubs: {
        GlFormGroup,
        GlLink,
        GlSprintf,
      },
    }),
  );
};

const findAiGatewayUrlInputForm = () => wrapper.findComponent(AiGtewayUrlInputForm);
const findLabelDescription = () => wrapper.findByTestId('label-description');
const findAiGatewaySetupLink = () => wrapper.findByTestId('ai-gateway-setup-link');
const findFormInput = () => wrapper.findComponent(GlFormInput);

describe('AiGatewayUrlInputForm', () => {
  beforeEach(() => {
    createComponent();
  });

  it('renders the component', () => {
    expect(findAiGatewayUrlInputForm().exists()).toBe(true);
  });

  it('has the correct label', () => {
    expect(findAiGatewayUrlInputForm().attributes('label')).toEqual('Local AI Gateway URL');
  });

  it('has the correct label description', () => {
    expect(findLabelDescription().text()).toMatch('Enter the URL for your local AI Gateway.');
    expect(findAiGatewaySetupLink().attributes('href')).toBe('/help/install/install_ai_gateway');
  });

  describe('form input', () => {
    it('renders the correct value', () => {
      expect(findFormInput().attributes('value')).toEqual(aiGatewayUrl);
    });

    it('emits a change event when updated', async () => {
      const newAiGatewayUrl = 'http://new-ai-gateway-url.com';
      findFormInput().vm.$emit('update', newAiGatewayUrl);

      await nextTick();

      expect(wrapper.emitted('change')).toEqual([[newAiGatewayUrl]]);
    });
  });
});
