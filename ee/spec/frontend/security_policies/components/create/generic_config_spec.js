import { shallowMount } from '@vue/test-utils';
import {
  GlButton,
  GlFormInput,
  GlFormSelect,
  GlFormTextarea,
  GlTableLite,
  GlToggle,
} from '@gitlab/ui';
import GenericConfig from 'ee/security_policies/components/create/generic_config.vue';
import MultiBadgeSelector from 'ee/security_policies/components/create/multi_badge_selector.vue';

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

  it('emits input with merged value on field update', () => {
    createComponent({
      fields: [{ key: 'txt', type: 'text', label: 'Text', placeholder: '' }],
      value: { existing: 'kept' },
    });

    wrapper.vm.update('txt', 'new value');

    expect(wrapper.emitted('input')[0][0]).toEqual({ existing: 'kept', txt: 'new value' });
  });

  it('emits input with nested matrix value on matrix update', () => {
    createComponent({
      fields: [{ key: 'sla', type: 'sla_matrix', label: 'SLA' }],
      value: { sla: { high: 5 } },
    });

    wrapper.vm.updateMatrix('sla', 'critical', 3);

    expect(wrapper.emitted('input')[0][0]).toEqual({ sla: { high: 5, critical: 3 } });
  });

  describe('segmentButtonClass', () => {
    it('returns active classes for the selected option', () => {
      createComponent({
        fields: [
          {
            key: 'seg',
            type: 'segment',
            label: 'Seg',
            options: [
              { id: 'a', label: 'A' },
              { id: 'b', label: 'B' },
            ],
          },
        ],
        value: { seg: 'b' },
      });

      expect(wrapper.vm.segmentButtonClass('seg', 'b', 'a')).toContain('gl-border-blue-500');
      expect(wrapper.vm.segmentButtonClass('seg', 'a', 'a')).toContain('gl-border-default');
    });

    it('defaults to first option active when no value is set', () => {
      createComponent({
        fields: [
          {
            key: 'seg',
            type: 'segment',
            label: 'Seg',
            options: [
              { id: 'a', label: 'A' },
              { id: 'b', label: 'B' },
            ],
          },
        ],
      });

      expect(wrapper.vm.segmentButtonClass('seg', 'a', 'a')).toContain('gl-border-blue-500');
      expect(wrapper.vm.segmentButtonClass('seg', 'b', 'a')).toContain('gl-border-default');
    });
  });
});
