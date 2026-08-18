import { mount, shallowMount } from '@vue/test-utils';
import {
  GlButton,
  GlFormCheckbox,
  GlFormInput,
  GlFormSelect,
  GlFormTextarea,
  GlTableLite,
  GlToggle,
} from '@gitlab/ui';
import GenericConfig from 'ee/policy_store/components/editor/generic_config.vue';
import MultiBadgeSelector from 'ee/policy_store/components/editor/multi_badge_selector.vue';
import RegoTemplatesModal from 'ee/policy_store/components/editor/rego_templates_modal.vue';

describe('GenericConfig', () => {
  let wrapper;

  const createComponent = ({ fields = [], value = {} } = {}) => {
    wrapper = shallowMount(GenericConfig, {
      propsData: { fields, value },
    });
  };

  it('renders GlToggle for type toggle', () => {
    createComponent({ fields: [{ key: 'myToggle', type: 'toggle', label: 'My Toggle' }] });

    expect(wrapper.findComponent(GlToggle).exists()).toBe(true);
  });

  it('renders GlFormCheckbox for type checkbox and defaults from field.default', () => {
    createComponent({
      fields: [{ key: 'denyUnlisted', type: 'checkbox', label: 'Deny unlisted', default: true }],
    });

    const checkbox = wrapper.findComponent(GlFormCheckbox);
    expect(checkbox.exists()).toBe(true);
    expect(checkbox.props('checked')).toBe(true);
  });

  it('renders MultiBadgeSelector for type multi_badge', () => {
    createComponent({
      fields: [{ key: 'badges', type: 'multi_badge', label: 'Badges', options: [] }],
    });

    expect(wrapper.findComponent(MultiBadgeSelector).exists()).toBe(true);
  });

  it('renders GlFormSelect for type select', () => {
    createComponent({
      fields: [{ key: 'sel', type: 'select', label: 'Select', options: [] }],
    });

    expect(wrapper.findComponent(GlFormSelect).exists()).toBe(true);
  });

  it('renders GlFormTextarea for type textarea', () => {
    createComponent({
      fields: [{ key: 'ta', type: 'textarea', label: 'TextArea', placeholder: '' }],
    });

    expect(wrapper.findComponent(GlFormTextarea).exists()).toBe(true);
  });

  describe('type code', () => {
    const codeField = {
      key: 'policy',
      type: 'code',
      label: 'Rego policy definition',
      maxLength: 100,
    };

    it('renders a Rego editor with a Browse templates button and modal', () => {
      createComponent({ fields: [codeField] });

      expect(wrapper.findComponent(GlFormTextarea).exists()).toBe(true);
      expect(wrapper.findComponent(RegoTemplatesModal).exists()).toBe(true);
      expect(wrapper.text()).toContain('Browse templates');
    });

    it('applies a selected template to the field', () => {
      createComponent({ fields: [codeField] });

      wrapper.findComponent(RegoTemplatesModal).vm.$emit('select', 'package foo');

      expect(wrapper.emitted('input')[0][0]).toEqual({ policy: 'package foo' });
    });
  });

  it('renders segment buttons for type segment', () => {
    createComponent({
      fields: [
        {
          key: 'seg',
          type: 'segment',
          label: 'Segment',
          options: [
            { id: 'a', label: 'A' },
            { id: 'b', label: 'B' },
          ],
        },
      ],
    });

    expect(wrapper.findAllComponents(GlButton)).toHaveLength(2);
  });

  it('renders GlTableLite for type sla_matrix', () => {
    createComponent({
      fields: [{ key: 'sla', type: 'sla_matrix', label: 'SLA Matrix' }],
    });

    expect(wrapper.findComponent(GlTableLite).exists()).toBe(true);
  });

  it('renders GlFormInput for text/unknown field types', () => {
    createComponent({
      fields: [{ key: 'txt', type: 'text', label: 'Text', placeholder: '' }],
    });

    expect(wrapper.findComponent(GlFormInput).exists()).toBe(true);
  });

  describe('defaults', () => {
    it('seeds every field declaring a default in a single update', () => {
      createComponent({
        fields: [
          { key: 'policy', type: 'code', label: 'Rego', default: 'package foo' },
          { key: 'denyUnlisted', type: 'checkbox', label: 'Deny unlisted', default: true },
          { key: 'sameRef', type: 'toggle', label: 'Same ref', default: true },
          { key: 'branch', type: 'text', label: 'Branch' },
        ],
      });

      expect(wrapper.emitted('input')).toEqual([
        [{ policy: 'package foo', denyUnlisted: true, sameRef: true }],
      ]);
    });

    it('keeps values already set rather than overwriting them with the default', () => {
      createComponent({
        fields: [{ key: 'denyUnlisted', type: 'checkbox', label: 'Deny unlisted', default: true }],
        value: { denyUnlisted: false },
      });

      expect(wrapper.emitted('input')).toBeUndefined();
    });

    it('seeds a default of false, which is a value rather than an absent one', () => {
      createComponent({
        fields: [{ key: 'sameRef', type: 'toggle', label: 'Same ref', default: false }],
      });

      expect(wrapper.emitted('input')).toEqual([[{ sameRef: false }]]);
    });

    it('emits nothing when no field declares a default', () => {
      createComponent({ fields: [{ key: 'branch', type: 'text', label: 'Branch' }] });

      expect(wrapper.emitted('input')).toBeUndefined();
    });
  });

  it('emits input with merged value when a field is edited', () => {
    createComponent({
      fields: [{ key: 'txt', type: 'text', label: 'Text', placeholder: '' }],
      value: { existing: 'kept' },
    });

    wrapper.findComponent(GlFormInput).vm.$emit('input', 'new value');

    expect(wrapper.emitted('input')[0][0]).toEqual({ existing: 'kept', txt: 'new value' });
  });

  it('emits input with nested matrix value when a severity is edited', () => {
    // Mounted rather than shallow: the severity inputs live in GlTableLite's cell slots.
    wrapper = mount(GenericConfig, {
      propsData: {
        fields: [{ key: 'sla', type: 'sla_matrix', label: 'SLA' }],
        value: { sla: { high: 5 } },
      },
    });

    // SLA_ITEMS order is critical, high, medium, low.
    wrapper.findAllComponents(GlFormInput).at(0).vm.$emit('input', 3);

    expect(wrapper.emitted('input')[0][0]).toEqual({ sla: { high: 5, critical: 3 } });
  });

  describe('type segment', () => {
    const segmentField = {
      key: 'seg',
      type: 'segment',
      label: 'Seg',
      options: [
        { id: 'a', label: 'A' },
        { id: 'b', label: 'B' },
      ],
    };

    const findSegmentButtons = () => wrapper.findAllComponents(GlButton);

    it('marks the selected option with the Pajamas selected state', () => {
      createComponent({ fields: [segmentField], value: { seg: 'b' } });

      expect(findSegmentButtons().wrappers.map((button) => button.props('selected'))).toEqual([
        false,
        true,
      ]);
    });

    it('treats the first option as selected when no value is set', () => {
      createComponent({ fields: [segmentField] });

      expect(findSegmentButtons().wrappers.map((button) => button.props('selected'))).toEqual([
        true,
        false,
      ]);
    });

    it('emits input when an option is clicked', () => {
      createComponent({ fields: [segmentField] });

      findSegmentButtons().at(1).vm.$emit('click');

      expect(wrapper.emitted('input')[0][0]).toEqual({ seg: 'b' });
    });
  });
});
