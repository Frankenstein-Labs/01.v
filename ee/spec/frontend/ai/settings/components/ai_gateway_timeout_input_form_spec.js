import { nextTick } from 'vue';
import { shallowMount } from '@vue/test-utils';
import { GlFormGroup, GlFormInput, GlSprintf } from '@gitlab/ui';
import AiGatewayTimeoutInputForm from 'ee/ai/settings/components/ai_gateway_timeout_input_form.vue';

let wrapper;

const defaultTimeout = 60;

const createComponent = ({ value = 60 } = {}) => {
  wrapper = shallowMount(AiGatewayTimeoutInputForm, {
    propsData: {
      value,
    },
    stubs: {
      GlFormGroup,
      GlSprintf,
    },
  });
};

const findAiGatewayTimeoutInputForm = () => wrapper.findComponent(AiGatewayTimeoutInputForm);
const findFormGroup = () => wrapper.findComponent(GlFormGroup);
const findFormInput = () => wrapper.findComponent(GlFormInput);

describe('AiGatewayTimeoutInputForm', () => {
  beforeEach(() => {
    createComponent();
  });

  it('renders the component', () => {
    expect(findAiGatewayTimeoutInputForm().exists()).toBe(true);
  });

  it('has the correct label', () => {
    expect(findFormGroup().attributes('label')).toBe('AI Gateway request timeout');
  });

  it('has the correct label description', () => {
    expect(findFormGroup().text()).toContain(
      'Maximum time in seconds to wait for responses from the AI Gateway (up to 600 seconds).',
    );
    expect(findFormGroup().text()).toContain(
      'Increasing this value might result in degraded user experience.',
    );
  });

  describe('form input', () => {
    it('renders with the correct initial value', () => {
      expect(findFormInput().attributes('value')).toBe(String(defaultTimeout));
    });

    it('has the correct input attributes', () => {
      expect(findFormInput().attributes('min')).toBe('60');
      expect(findFormInput().attributes('max')).toBe('600');
    });

    it('emits the change event when input is changed', async () => {
      const newTimeout = 450;

      findFormInput().vm.$emit('input', newTimeout);
      await nextTick();

      expect(wrapper.emitted('change')).toEqual([[newTimeout]]);
    });
  });
});
