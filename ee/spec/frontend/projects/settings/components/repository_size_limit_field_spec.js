import { GlFormGroup, GlFormInput } from '@gitlab/ui';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import RepositorySizeLimitField from 'ee/projects/settings/components/repository_size_limit_field.vue';

describe('RepositorySizeLimitField', () => {
  let wrapper;

  const createComponent = (props = {}) => {
    wrapper = mountExtended(RepositorySizeLimitField, {
      propsData: props,
    });
  };

  const findFormGroup = () => wrapper.findComponent(GlFormGroup);
  const findInput = () => wrapper.findComponent(GlFormInput);

  it('renders a number input bound to project[repository_size_limit]', () => {
    createComponent({ value: 100 });

    const input = findInput();
    expect(input.attributes('name')).toBe('project[repository_size_limit]');
    expect(input.attributes('type')).toBe('number');
    expect(input.props('value')).toBe(100);
  });

  it('emits `input` when the value changes', () => {
    createComponent({ value: 100 });

    findInput().vm.$emit('input', 200);

    expect(wrapper.emitted('input')).toEqual([[200]]);
  });

  it('renders the help text as HTML in the description', () => {
    createComponent({ value: 100, helpText: 'Max size <a href="#">Learn more</a>' });

    expect(findFormGroup().text()).toContain('Max size');
    // The anchor must be rendered as markup, not escaped text.
    expect(findFormGroup().find('a').text()).toBe('Learn more');
  });
});
