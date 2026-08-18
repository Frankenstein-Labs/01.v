import { GlFormInput, GlFormTextarea } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import PolicyNameField from 'ee/policy_store/components/editor/policy_name_field.vue';

describe('PolicyNameField', () => {
  let wrapper;

  const createComponent = (propsData = {}) => {
    wrapper = shallowMountExtended(PolicyNameField, { propsData });
  };

  const findName = () => wrapper.findComponent(GlFormInput);
  const findDescription = () => wrapper.findComponent(GlFormTextarea);
  const findPanel = () => wrapper.findByTestId('description-panel');

  const openDescription = () => findName().vm.$emit('focus');

  it('starts with an empty name by default', () => {
    createComponent();

    expect(findName().props('value')).toBe('');
  });

  it('seeds the name and description', async () => {
    createComponent({ name: 'My policy', description: 'Some description' });
    await openDescription();

    expect(findName().props('value')).toBe('My policy');
    expect(findDescription().props('value')).toBe('Some description');
  });

  it('emits update:name as the name is edited', () => {
    createComponent();

    findName().vm.$emit('input', 'New name');

    expect(wrapper.emitted('update:name')).toEqual([['New name']]);
  });

  it('emits update:description as the description is edited', async () => {
    createComponent();
    await openDescription();

    findDescription().vm.$emit('input', 'What it does');

    expect(wrapper.emitted('update:description')).toEqual([['What it does']]);
  });

  it('hides the description panel until the name is focused', async () => {
    createComponent();

    expect(findPanel().exists()).toBe(false);

    await openDescription();

    expect(findPanel().exists()).toBe(true);
  });

  it('closes the description panel when Escape is pressed', async () => {
    createComponent();
    await openDescription();

    await wrapper.trigger('keydown.esc');

    expect(findPanel().exists()).toBe(false);
  });

  it('closes the description panel when focus moves outside', async () => {
    createComponent();
    await openDescription();

    await wrapper.trigger('focusout', { relatedTarget: document.body });

    expect(findPanel().exists()).toBe(false);
  });

  it('keeps the description panel open while focus stays within it', async () => {
    createComponent();
    await openDescription();

    await wrapper.trigger('focusout', { relatedTarget: findPanel().element });

    expect(findPanel().exists()).toBe(true);
  });
});
