import { shallowMount } from '@vue/test-utils';
import { GlFormRadio, GlFormRadioGroup } from '@gitlab/ui';
import CodeSuggestionsConnectionForm from 'ee/ai/settings/components/code_suggestions_connection_form.vue';

describe('CodeSuggestionsConnectionForm', () => {
  let wrapper;

  const createComponent = (props = {}) => {
    return shallowMount(CodeSuggestionsConnectionForm, {
      propsData: {
        ...props,
      },
      provide: {
        disabledDirectConnectionMethod: false,
      },
    });
  };

  const findFormRadioButtons = () => wrapper.findAllComponents(GlFormRadio);
  const findFormRadioGroup = () => wrapper.findComponent(GlFormRadioGroup);

  beforeEach(() => {
    wrapper = createComponent();
  });

  it('renders radio buttons', () => {
    expect(findFormRadioButtons()).toHaveLength(2);
  });

  it('sets correct values for radio buttons', () => {
    expect(findFormRadioButtons().at(0).attributes('value')).toBeUndefined();
    expect(findFormRadioButtons().at(1).attributes('value')).toBe('true');
  });

  it('emits change event to parent when radio option is updated', () => {
    findFormRadioGroup().vm.$emit('change', true);
    expect(wrapper.emitted('change')).toStrictEqual([[true]]);
  });
});
