import { GlFormInput, GlSprintf } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import EpssFilter from 'ee/security_orchestration/components/policy_editor/scan_result/rule/scan_filters/epss_filter.vue';
import SectionLayout from 'ee/security_orchestration/components/policy_editor/section_layout.vue';
import {
  EPSS_OPERATOR_ITEMS,
  EPSS_OPERATOR_VALUE_ITEMS,
  LOW_RISK,
  MODERATE_RISK,
  HIGH_RISK,
  CRITICAL_RISK,
  CUSTOM_VALUE,
} from 'ee/security_orchestration/components/policy_editor/scan_result/rule/scan_filters/constants';
import {
  LESS_THAN_OPERATOR,
  GREATER_THAN_OPERATOR,
} from 'ee/security_orchestration/components/policy_editor/constants';

describe('EpssFilter', () => {
  let wrapper;

  const defaultProps = {
    selectedOperator: LESS_THAN_OPERATOR,
    selectedValue: 0.5,
  };

  const createWrapper = (props = {}) => {
    wrapper = shallowMountExtended(EpssFilter, {
      propsData: {
        ...defaultProps,
        ...props,
      },
      stubs: {
        GlSprintf,
      },
    });
  };

  const findSectionLayout = () => wrapper.findComponent(SectionLayout);
  const findOperatorListbox = () => wrapper.findComponentByTestId('operator-list');
  const findValueListbox = () => wrapper.findComponentByTestId('value-list');
  const findCustomValueInput = () => wrapper.findComponent(GlFormInput);

  describe('default rendering', () => {
    beforeEach(() => {
      createWrapper();
    });

    it('renders section layout with correct props', () => {
      const sectionLayout = findSectionLayout();

      expect(sectionLayout.exists()).toBe(true);
      expect(sectionLayout.props('ruleLabel')).toBe('EPSS has a');
      expect(sectionLayout.props('showRemoveButton')).toBe(false);
    });

    it('renders operator listbox with correct props', () => {
      const operatorListbox = findOperatorListbox();

      expect(operatorListbox.exists()).toBe(true);
      expect(operatorListbox.props('items')).toEqual(EPSS_OPERATOR_ITEMS);
      expect(operatorListbox.props('selected')).toBe(LESS_THAN_OPERATOR);
    });

    it('renders value listbox with correct props', () => {
      const valueListbox = findValueListbox();

      expect(valueListbox.exists()).toBe(true);
      expect(valueListbox.props('items')).toEqual(EPSS_OPERATOR_VALUE_ITEMS);
    });

    it('does not render custom value input by default', () => {
      expect(findCustomValueInput().exists()).toBe(false);
    });
  });

  describe('with no selected operator', () => {
    beforeEach(() => {
      createWrapper({ selectedOperator: '' });
    });

    it('uses fallback operator for listbox selection', () => {
      const operatorListbox = findOperatorListbox();

      expect(operatorListbox.props('selected')).toBe('');
      expect(operatorListbox.props('toggleText')).toBe('Select operator');
    });
  });

  describe('with selected operator', () => {
    beforeEach(() => {
      createWrapper({ selectedOperator: GREATER_THAN_OPERATOR });
    });

    it('displays correct operator text', () => {
      expect(findOperatorListbox().props('toggleText')).toBe('greater than');
    });
  });

  describe('value handling', () => {
    it.each([
      { value: 0.1, expectedText: LOW_RISK },
      { value: 0.5, expectedText: MODERATE_RISK },
      { value: 0.8, expectedText: HIGH_RISK },
      { value: 1.0, expectedText: CRITICAL_RISK },
      { value: 0.3, expectedText: CUSTOM_VALUE },
    ])('displays correct value text for value $value', ({ value, expectedText }) => {
      createWrapper({ selectedValue: value });

      expect(findValueListbox().props('toggleText')).toBe(expectedText);
    });

    it('sanitizes values greater than 1', () => {
      createWrapper({ selectedValue: 1.5 });

      expect(findValueListbox().props('toggleText')).toBe(CRITICAL_RISK);
    });

    it('sanitizes values less than 0', () => {
      createWrapper({ selectedValue: -0.5 });

      expect(findValueListbox().props('toggleText')).toBe('Select probability');
    });

    it('handles NaN values', () => {
      createWrapper({ selectedValue: NaN });

      expect(findValueListbox().props('toggleText')).toBe('Select probability');
    });

    it('renders custom input field for custom values', () => {
      createWrapper({ selectedValue: 0.2 });

      expect(findCustomValueInput().exists()).toBe(true);
      expect(findCustomValueInput().props('value')).toBe(0.2);
    });
  });

  describe('operator selection', () => {
    beforeEach(() => {
      createWrapper();
    });

    it('emits select event when operator is changed', async () => {
      await findOperatorListbox().vm.$emit('select', GREATER_THAN_OPERATOR);

      expect(wrapper.emitted('select')).toHaveLength(1);
      expect(wrapper.emitted('select')[0]).toEqual([
        {
          operator: GREATER_THAN_OPERATOR,
          value: 0.5,
        },
      ]);
    });
  });

  describe('value selection', () => {
    beforeEach(() => {
      createWrapper();
    });

    it('emits select event with extracted percentage for predefined values', async () => {
      await findValueListbox().vm.$emit('select', LOW_RISK);

      expect(wrapper.emitted('select')).toHaveLength(1);
      expect(wrapper.emitted('select')[0]).toEqual([
        {
          operator: LESS_THAN_OPERATOR,
          value: 0.1,
        },
      ]);
    });

    it('shows custom input and emits default value for custom selection', async () => {
      await findValueListbox().vm.$emit('select', CUSTOM_VALUE);

      expect(wrapper.emitted('select')).toHaveLength(1);
      expect(wrapper.emitted('select')[0]).toEqual([
        {
          operator: LESS_THAN_OPERATOR,
          value: 0.2,
        },
      ]);

      expect(findCustomValueInput().exists()).toBe(true);
    });
  });

  describe('custom value input', () => {
    beforeEach(async () => {
      createWrapper();
      await findValueListbox().vm.$emit('select', CUSTOM_VALUE);
    });

    it('renders custom input with correct props', () => {
      const customInput = findCustomValueInput();

      expect(customInput.exists()).toBe(true);
      expect(customInput.props('type')).toBe('number');
      expect(customInput.props('max')).toBe('1');
      expect(customInput.props('min')).toBe('0');
      expect(customInput.props('value')).toBe(0.5);
    });

    it('emits select event when custom value is changed', async () => {
      const customInput = findCustomValueInput();

      await customInput.vm.$emit('input', '0.75');

      expect(wrapper.emitted('select')).toHaveLength(2); // First from triggering custom mode
      expect(wrapper.emitted('select')[1]).toEqual([
        {
          operator: LESS_THAN_OPERATOR,
          value: 0.75,
        },
      ]);
    });
  });

  describe('edge cases', () => {
    it('handles empty selectedOperator with fallback', () => {
      createWrapper({ selectedOperator: '' });

      expect(findOperatorListbox().props('toggleText')).toBe('Select operator');
    });

    it('handles invalid selectedValue', () => {
      createWrapper({ selectedValue: NaN });

      expect(findValueListbox().props('toggleText')).toBe('Select probability');
    });
  });

  describe('accessibility', () => {
    beforeEach(() => {
      createWrapper();
    });

    it('has proper form structure', () => {
      expect(findSectionLayout().exists()).toBe(true);
      expect(findOperatorListbox().exists()).toBe(true);
      expect(findValueListbox().exists()).toBe(true);
    });

    it('provides proper labels through section layout', () => {
      expect(findSectionLayout().props('ruleLabel')).toBe('EPSS has a');
    });
  });
});
