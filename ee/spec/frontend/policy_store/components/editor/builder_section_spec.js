import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import BuilderSection from 'ee/policy_store/components/editor/builder_section.vue';
import GenericConfig from 'ee/policy_store/components/editor/generic_config.vue';

describe('BuilderSection', () => {
  let wrapper;

  const entry = (id, overrides = {}) => ({
    id,
    label: `Label ${id}`,
    description: `about ${id}`,
    icon: 'shield',
    fields: [{ key: 'environment', label: 'Environment', type: 'text' }],
    config: {},
    ...overrides,
  });

  const section = (overrides = {}) => ({
    id: 'rules',
    heading: 'Rules',
    description: 'What conditions must be met?',
    addLabel: 'Add rule',
    joiner: 'AND',
    entries: [],
    ...overrides,
  });

  const createComponent = (overrides = {}) => {
    wrapper = shallowMountExtended(BuilderSection, {
      propsData: { section: section(overrides) },
    });
  };

  const findSelected = () => wrapper.findAllByTestId('rules-selected');
  const findAdd = () => wrapper.findComponentByTestId('rules-add');
  const findRemoveButtons = () => wrapper.findAllComponentsByTestId('rules-selected-remove');

  it('renders the heading and description', () => {
    createComponent();

    expect(wrapper.text()).toContain('Rules');
    expect(wrapper.text()).toContain('What conditions must be met?');
  });

  it('offers an add button only while the section is empty, and emits add', () => {
    createComponent();

    findAdd().vm.$emit('click');

    expect(wrapper.emitted('add')).toHaveLength(1);

    createComponent({ entries: [entry('a')] });

    expect(findAdd().exists()).toBe(false);
  });

  it('renders every entry with the joiner between them, not before the first', () => {
    createComponent({ entries: [entry('a'), entry('b')] });

    expect(findSelected()).toHaveLength(2);
    expect(wrapper.text().match(/AND/g)).toHaveLength(1);
  });

  it('emits remove with the entry id', () => {
    createComponent({ entries: [entry('a'), entry('b')] });

    findRemoveButtons().at(1).vm.$emit('click');

    expect(wrapper.emitted('remove')).toEqual([['b']]);
  });

  it('renders the config form for an entry with fields', () => {
    createComponent({ entries: [entry('a', { config: { environment: 'prod' } })] });

    expect(wrapper.findComponent(GenericConfig).props()).toMatchObject({
      fields: [{ key: 'environment', label: 'Environment', type: 'text' }],
      value: { environment: 'prod' },
    });
  });

  it('renders no config form for an entry without fields', () => {
    createComponent({ entries: [entry('a', { fields: [] })] });

    expect(wrapper.findComponent(GenericConfig).exists()).toBe(false);
  });

  it('re-emits a config change with the entry id', () => {
    createComponent({ entries: [entry('a')] });

    wrapper.findComponent(GenericConfig).vm.$emit('input', { environment: 'prod' });

    expect(wrapper.emitted('update-config')).toEqual([
      [{ id: 'a', config: { environment: 'prod' } }],
    ]);
  });

  it('names each remove button after its entry, so repeated ones stay distinguishable', () => {
    createComponent({ entries: [entry('a'), entry('b')] });

    expect(findRemoveButtons().wrappers.map((button) => button.attributes('aria-label'))).toEqual([
      'Remove Label a',
      'Remove Label b',
    ]);
  });
});
