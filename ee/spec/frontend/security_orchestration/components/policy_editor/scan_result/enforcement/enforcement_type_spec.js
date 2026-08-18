import { GlAlert, GlBadge, GlFormGroup, GlFormRadioGroup, GlFormRadio, GlIcon } from '@gitlab/ui';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import EnforcementType from 'ee/security_orchestration/components/policy_editor/scan_result/enforcement/enforcement_type.vue';
import {
  ENFORCE_VALUE,
  WARN_VALUE,
} from 'ee/security_orchestration/components/policy_editor/scan_result/lib/enforcement';

describe('EnforcementType', () => {
  let wrapper;

  const factory = (propsData = {}) => {
    wrapper = mountExtended(EnforcementType, {
      propsData: {
        enforcement: ENFORCE_VALUE,
        ...propsData,
      },
    });
  };

  const findFormGroup = () => wrapper.findComponent(GlFormGroup);
  const findRadioGroup = () => wrapper.findComponent(GlFormRadioGroup);
  const findRadios = () => wrapper.findAllComponents(GlFormRadio);
  const findRadioByValue = (value) =>
    findRadios().wrappers.find((radio) =>
      radio.find(`[data-testid="enforcement-radio-${value}"]`).exists(),
    );
  const findEnforceRadio = () => findRadioByValue(ENFORCE_VALUE);
  const findWarnRadio = () => findRadioByValue(WARN_VALUE);
  const findEnforceIcon = () => findEnforceRadio().findComponent(GlIcon);
  const findWarnIcon = () => findWarnRadio().findComponent(GlIcon);

  describe('layout', () => {
    beforeEach(() => factory());

    it('renders the form group with the Enforcement mode label', () => {
      expect(findFormGroup().exists()).toBe(true);
      expect(wrapper.find('legend').text()).toBe('Enforcement mode');
    });

    it('renders a radio group bound to the enforcement value', () => {
      expect(findRadioGroup().exists()).toBe(true);
      expect(findRadioGroup().props('checked')).toBe(ENFORCE_VALUE);
    });

    it('renders both enforcement radios, Enforce first', () => {
      const radios = findRadios();

      expect(radios).toHaveLength(2);
      expect(radios.at(0).props('value')).toBe(ENFORCE_VALUE);
      expect(radios.at(1).props('value')).toBe(WARN_VALUE);
    });

    it('renders the title and description for the Enforce radio', () => {
      expect(findEnforceRadio().text()).toContain('Enforce');
      expect(findEnforceRadio().text()).toContain(
        'Hard enforcement. Violations are blocked as defined.',
      );
    });

    it('renders the title and description for the Warn radio', () => {
      expect(findWarnRadio().text()).toContain('Warn');
      expect(findWarnRadio().text()).toContain(
        'Advisory mode. Violations are flagged but progress is not blocked.',
      );
    });

    it('does not render any GlAlert', () => {
      expect(wrapper.findComponent(GlAlert).exists()).toBe(false);
    });

    it('does not render any GlBadge', () => {
      expect(wrapper.findComponent(GlBadge).exists()).toBe(false);
    });

    it('renders the failed status icon on the Enforce radio', () => {
      expect(findEnforceIcon().props('name')).toBe('status-failed');
      expect(findEnforceIcon().classes()).toContain('gl-text-danger');
    });

    it('renders the alert status icon on the Warn radio', () => {
      expect(findWarnIcon().props('name')).toBe('status-alert');
      expect(findWarnIcon().classes()).toContain('gl-text-warning');
    });
  });

  describe('selection state', () => {
    it('reflects the enforcement prop on the radio group (Enforce)', () => {
      factory({ enforcement: ENFORCE_VALUE });

      expect(findRadioGroup().props('checked')).toBe(ENFORCE_VALUE);
    });

    it('reflects the enforcement prop on the radio group (Warn)', () => {
      factory({ enforcement: WARN_VALUE });

      expect(findRadioGroup().props('checked')).toBe(WARN_VALUE);
    });
  });

  describe('events', () => {
    it('emits change with "warn" when the radio group selects warn', async () => {
      factory({ enforcement: ENFORCE_VALUE });

      await findRadioGroup().vm.$emit('change', WARN_VALUE);

      expect(wrapper.emitted('change')).toEqual([[WARN_VALUE]]);
    });

    it('emits change with "enforce" when the radio group selects enforce', async () => {
      factory({ enforcement: WARN_VALUE });

      await findRadioGroup().vm.$emit('change', ENFORCE_VALUE);

      expect(wrapper.emitted('change')).toEqual([[ENFORCE_VALUE]]);
    });
  });
});
