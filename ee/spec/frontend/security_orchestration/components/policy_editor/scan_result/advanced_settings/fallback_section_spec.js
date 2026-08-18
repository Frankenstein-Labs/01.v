import { shallowMount } from '@vue/test-utils';
import { GlFormRadio, GlFormRadioGroup } from '@gitlab/ui';
import { OPEN } from 'ee/security_orchestration/components/policy_editor/scan_result/advanced_settings/constants';
import FallbackSection from 'ee/security_orchestration/components/policy_editor/scan_result/advanced_settings/fallback_section.vue';

describe('FallbackSection', () => {
  let wrapper;

  const createComponent = (propsData = {}) => {
    wrapper = shallowMount(FallbackSection, {
      propsData: { property: OPEN, ...propsData },
    });
  };

  const findAllRadioButtons = () => wrapper.findAllComponents(GlFormRadio);
  const findRadioGroup = () => wrapper.findComponent(GlFormRadioGroup);

  it('renders the radio buttons', () => {
    createComponent();
    expect(findAllRadioButtons()).toHaveLength(2);
    expect(findAllRadioButtons().at(0).text()).toBe('Fail open');
    expect(findAllRadioButtons().at(1).text()).toBe('Fail closed');
  });

  it('emits when a radio button is clicked', () => {
    createComponent();
    findRadioGroup().vm.$emit('change', OPEN);
    expect(wrapper.emitted('changed')).toEqual([['fallback_behavior', { fail: OPEN }]]);
  });
});
