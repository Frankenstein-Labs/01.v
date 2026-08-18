import { GlSprintf } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import VulnerabilitiesAllowedSection from 'ee/security_orchestration/components/policy_editor/scan_result/rule/scanners/vulnerabilities_allowed_section.vue';
import NumberRangeSelect from 'ee/security_orchestration/components/policy_editor/scan_result/rule/number_range_select.vue';
import {
  ANY_OPERATOR,
  GREATER_THAN_OPERATOR,
} from 'ee/security_orchestration/components/policy_editor/constants';

describe('VulnerabilitiesAllowedSection', () => {
  let wrapper;

  const createComponent = (props = {}) => {
    wrapper = shallowMountExtended(VulnerabilitiesAllowedSection, {
      propsData: {
        ...props,
      },
      stubs: {
        GlSprintf,
      },
    });
  };

  const findNumberRangeSelect = () => wrapper.findComponent(NumberRangeSelect);

  describe('rendering', () => {
    it('renders the sentence text', () => {
      createComponent();

      expect(wrapper.text()).toContain(
        'vulnerability type that matches all the following criteria',
      );
    });

    it('renders NumberRangeSelect with correct props', () => {
      createComponent();

      const numberRangeSelect = findNumberRangeSelect();
      expect(numberRangeSelect.exists()).toBe(true);
      expect(numberRangeSelect.props('id')).toBe('scanner-vulnerabilities-allowed');
      expect(numberRangeSelect.props('value')).toBe(0);
    });
  });

  describe('operator selection', () => {
    it('selects ANY operator when vulnerabilitiesAllowed is 0', () => {
      createComponent({ vulnerabilitiesAllowed: 0 });

      expect(findNumberRangeSelect().props('selected')).toBe(ANY_OPERATOR);
    });

    it('selects GREATER_THAN operator when vulnerabilitiesAllowed is non-zero', () => {
      createComponent({ vulnerabilitiesAllowed: 5 });

      expect(findNumberRangeSelect().props('selected')).toBe(GREATER_THAN_OPERATOR);
    });
  });

  describe('events', () => {
    it('emits input with 0 when operator changes to ANY', () => {
      createComponent({ vulnerabilitiesAllowed: 5 });

      findNumberRangeSelect().vm.$emit('operator-change', ANY_OPERATOR);

      expect(wrapper.emitted('input')).toEqual([[0]]);
    });

    it('does not emit input when operator changes to GREATER_THAN', () => {
      createComponent();

      findNumberRangeSelect().vm.$emit('operator-change', GREATER_THAN_OPERATOR);

      expect(wrapper.emitted('input')).toBeUndefined();
    });

    it('emits input when number value is changed', () => {
      createComponent();

      findNumberRangeSelect().vm.$emit('input', 3);

      expect(wrapper.emitted('input')).toEqual([[3]]);
    });
  });

  describe('default props', () => {
    it('defaults vulnerabilitiesAllowed to 0', () => {
      createComponent();

      expect(findNumberRangeSelect().props('value')).toBe(0);
      expect(findNumberRangeSelect().props('selected')).toBe(ANY_OPERATOR);
    });
  });
});
