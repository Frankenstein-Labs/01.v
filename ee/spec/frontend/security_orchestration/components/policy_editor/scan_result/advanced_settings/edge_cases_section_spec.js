import { nextTick } from 'vue';
import { shallowMount } from '@vue/test-utils';
import { GlFormCheckbox, GlPopover, GlFormInput, GlFormGroup } from '@gitlab/ui';
import EdgeCasesSection from 'ee/security_orchestration/components/policy_editor/scan_result/advanced_settings/edge_cases_section.vue';

describe('EdgeCasesSection', () => {
  let wrapper;

  const createComponent = (propsData = {}) => {
    wrapper = shallowMount(EdgeCasesSection, {
      propsData: { policyTuning: { unblock_rules_using_execution_policies: false }, ...propsData },
    });
  };

  const findUnblockRulesCheckbox = () => wrapper.findAllComponents(GlFormCheckbox).at(0);
  const findTimeWindowCheckbox = () => wrapper.findAllComponents(GlFormCheckbox).at(1);
  const findPopover = () => wrapper.findComponent(GlPopover);

  const findTimeWindowInput = () => wrapper.findComponent(GlFormInput);
  const findTimeWindowGroup = () => wrapper.findComponent(GlFormGroup);

  describe('default state when edge cases setting is not selected', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders the unblock rules checkbox', () => {
      expect(findUnblockRulesCheckbox().text()).toContain(
        'Make approval rules optional using execution policies',
      );
      expect(findUnblockRulesCheckbox().attributes('checked')).toBeUndefined();
    });

    it('renders the popover', () => {
      expect(findPopover().exists()).toBe(true);
    });

    it('emits when unblock rules checkbox is clicked', () => {
      findUnblockRulesCheckbox().vm.$emit('change', true);
      expect(wrapper.emitted('changed')).toEqual([
        ['policy_tuning', { unblock_rules_using_execution_policies: true }],
      ]);
    });
  });

  describe('when edge cases setting is selected', () => {
    it('renders the selected unblock rules checkbox when YAML value is enabled', () => {
      createComponent({ policyTuning: { unblock_rules_using_execution_policies: true } });
      expect(findUnblockRulesCheckbox().attributes('checked')).toBe('true');
    });
  });

  describe('time window feature', () => {
    it('renders time window checkbox when feature flag is enabled', () => {
      createComponent();
      expect(findTimeWindowCheckbox().exists()).toBe(true);
      expect(findTimeWindowCheckbox().text()).toContain(
        'Use time window for target pipeline comparison',
      );
    });

    it('renders time window input when time window is enabled', () => {
      createComponent({ policyTuning: { security_report_time_window: 60 } });
      expect(findTimeWindowInput().exists()).toBe(true);
      expect(findTimeWindowGroup().exists()).toBe(true);
      expect(findTimeWindowInput().attributes('value')).toBe('60');
    });

    it('does not render time window input when time window is not enabled', () => {
      createComponent();
      expect(findTimeWindowInput().exists()).toBe(false);
      expect(findTimeWindowGroup().exists()).toBe(false);
    });

    it('enables time window when checkbox is checked', async () => {
      createComponent();
      findTimeWindowCheckbox().vm.$emit('change', true);
      await nextTick();

      expect(findTimeWindowInput().exists()).toBe(true);
      expect(wrapper.emitted('changed')).toEqual([
        [
          'policy_tuning',
          { unblock_rules_using_execution_policies: false, security_report_time_window: 1 },
        ],
      ]);
    });

    it('disables time window when checkbox is unchecked', async () => {
      createComponent({ policyTuning: { security_report_time_window: 60 } });
      findTimeWindowCheckbox().vm.$emit('change', false);
      await nextTick();

      expect(findTimeWindowInput().exists()).toBe(false);
      expect(wrapper.emitted('changed')).toEqual([
        ['policy_tuning', { security_report_time_window: undefined }],
      ]);
    });

    it('emits when time window input value changes', () => {
      createComponent({ policyTuning: { security_report_time_window: 60 } });
      findTimeWindowInput().vm.$emit('input', '120');
      expect(wrapper.emitted('changed')).toEqual([
        ['policy_tuning', { security_report_time_window: 120 }],
      ]);
    });

    it('validates time window input range', () => {
      createComponent({ policyTuning: { security_report_time_window: 60 } });
      findTimeWindowInput().vm.$emit('input', '0');
      expect(wrapper.emitted('changed')).toBeUndefined();

      findTimeWindowInput().vm.$emit('input', '10081');
      expect(wrapper.emitted('changed')).toBeUndefined();
    });
  });
});
