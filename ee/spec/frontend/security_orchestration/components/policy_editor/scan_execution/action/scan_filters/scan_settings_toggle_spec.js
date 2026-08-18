import { GlToggle } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import SectionLayout from 'ee/security_orchestration/components/policy_editor/section_layout.vue';
import ScanSettingsToggle from 'ee/security_orchestration/components/policy_editor/scan_execution/action/scan_filters/scan_settings_toggle.vue';

describe('ScanSettingsToggle', () => {
  let wrapper;

  const createComponent = (propsData = {}) => {
    wrapper = shallowMountExtended(ScanSettingsToggle, {
      propsData,
      stubs: {
        SectionLayout,
      },
    });
  };

  const findToggle = () => wrapper.findComponent(GlToggle);

  it('renders toggle with default value', () => {
    createComponent();
    expect(findToggle().props('value')).toBe(false);
  });

  it('renders toggle with selected value', () => {
    createComponent({ selected: true });
    expect(findToggle().props('value')).toBe(true);
  });

  it('renders correct toggle label and description', () => {
    createComponent();
    expect(findToggle().props('labelPosition')).toBe('hidden');
    expect(wrapper.text()).toContain('Ignore default CI configuration for before/after script');
    expect(wrapper.text()).toContain(
      'Prevents project before script and after script from interfering with scan execution.',
    );
  });

  it('emits "input" event when toggle is enabled', () => {
    createComponent();
    expect(wrapper.emitted('input')).toEqual(undefined);
    expect(wrapper.emitted('remove')).toEqual(undefined);

    findToggle().vm.$emit('change', true);

    expect(wrapper.emitted('input')).toEqual([
      [{ scan_settings: { ignore_default_before_after_script: true } }],
    ]);
    expect(wrapper.emitted('remove')).toEqual(undefined);
  });

  it('emits "remove" event when toggle is disabled', () => {
    createComponent({ selected: true });
    expect(wrapper.emitted('input')).toEqual(undefined);
    expect(wrapper.emitted('remove')).toEqual(undefined);

    findToggle().vm.$emit('change', false);

    expect(wrapper.emitted('input')).toEqual(undefined);
    expect(wrapper.emitted('remove')).toEqual([[]]);
  });
});
