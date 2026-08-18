import { GlSprintf } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import BranchRuleSection from 'ee/security_orchestration/components/policy_editor/scan_result/rule/scanners/branch_rule_section.vue';
import BranchSelection from 'ee/security_orchestration/components/policy_editor/branch_selection.vue';
import BranchExceptionSelector from 'ee/security_orchestration/components/policy_editor/branch_exception_selector.vue';
import NumberRangeSelect from 'ee/security_orchestration/components/policy_editor/scan_result/rule/number_range_select.vue';
import SectionLayout from 'ee/security_orchestration/components/policy_editor/section_layout.vue';
import { ANY_OPERATOR } from 'ee/security_orchestration/components/policy_editor/constants';

describe('BranchRuleSection', () => {
  let wrapper;

  const defaultScanner = {
    type: 'scan_finding',
    branches: [],
    scanners: ['dast'],
    vulnerabilities_allowed: 0,
    severity_levels: [],
    vulnerability_states: [],
  };

  const defaultBranchTypes = [
    { value: 'default', text: 'Default branch' },
    { value: 'protected', text: 'All protected branches' },
  ];

  const createComponent = (props = {}) => {
    wrapper = shallowMountExtended(BranchRuleSection, {
      propsData: {
        scanner: defaultScanner,
        branchTypes: defaultBranchTypes,
        branchExceptions: [],
        vulnerabilitiesAllowed: 0,
        selectedOperator: ANY_OPERATOR,
        ...props,
      },
      stubs: {
        GlSprintf,
      },
    });
  };

  const findSectionLayout = () => wrapper.findComponent(SectionLayout);
  const findBranchSelection = () => wrapper.findComponent(BranchSelection);
  const findBranchExceptionSelector = () => wrapper.findComponent(BranchExceptionSelector);
  const findNumberRangeSelect = () => wrapper.findComponent(NumberRangeSelect);

  describe('rendering', () => {
    it('renders all components correctly', () => {
      createComponent();

      expect(findSectionLayout().exists()).toBe(true);
      expect(findBranchSelection().exists()).toBe(true);
      expect(findBranchExceptionSelector().exists()).toBe(true);
      expect(findNumberRangeSelect().exists()).toBe(true);
    });
  });

  describe('props', () => {
    it('passes scanner to BranchSelection as init-rule', () => {
      createComponent();

      expect(findBranchSelection().props('initRule')).toEqual(defaultScanner);
    });

    it('passes branchTypes to BranchSelection', () => {
      createComponent();

      expect(findBranchSelection().props('branchTypes')).toEqual(defaultBranchTypes);
    });

    it('passes branchExceptions to BranchExceptionSelector', () => {
      const branchExceptions = ['main', 'develop'];
      createComponent({ branchExceptions });

      expect(findBranchExceptionSelector().props('selectedExceptions')).toEqual(branchExceptions);
    });

    it('passes vulnerabilitiesAllowed to NumberRangeSelect', () => {
      createComponent({ vulnerabilitiesAllowed: 5 });

      expect(findNumberRangeSelect().props('value')).toBe(5);
    });

    it('passes selectedOperator to NumberRangeSelect', () => {
      const selectedOperator = 'greater_than';
      createComponent({ selectedOperator });

      expect(findNumberRangeSelect().props('selected')).toBe(selectedOperator);
    });
  });

  describe('events', () => {
    beforeEach(() => {
      createComponent();
    });

    it('emits changed event when BranchSelection emits changed', () => {
      const payload = { branches: ['main'] };

      findBranchSelection().vm.$emit('changed', payload);

      expect(wrapper.emitted('changed')).toHaveLength(1);
      expect(wrapper.emitted('changed')[0][0]).toEqual(payload);
    });

    it('emits set-branch-type event when BranchSelection emits set-branch-type', () => {
      const payload = { branch_type: 'protected' };

      findBranchSelection().vm.$emit('set-branch-type', payload);

      expect(wrapper.emitted('set-branch-type')).toHaveLength(1);
      expect(wrapper.emitted('set-branch-type')[0][0]).toEqual(payload);
    });

    it('emits remove-exceptions event when BranchExceptionSelector emits remove', () => {
      findBranchExceptionSelector().vm.$emit('remove');

      expect(wrapper.emitted('remove-exceptions')).toHaveLength(1);
    });

    it('emits changed event when BranchExceptionSelector emits select', () => {
      const payload = { branch_exceptions: ['main'] };

      findBranchExceptionSelector().vm.$emit('select', payload);

      expect(wrapper.emitted('changed')).toHaveLength(1);
      expect(wrapper.emitted('changed')[0][0]).toEqual(payload);
    });

    it('emits operator-change event when NumberRangeSelect emits operator-change', () => {
      const operator = 'greater_than';

      findNumberRangeSelect().vm.$emit('operator-change', operator);

      expect(wrapper.emitted('operator-change')).toHaveLength(1);
      expect(wrapper.emitted('operator-change')[0][0]).toBe(operator);
    });

    it('emits range-input event when NumberRangeSelect emits input', () => {
      const value = 10;

      findNumberRangeSelect().vm.$emit('input', value);

      expect(wrapper.emitted('range-input')).toHaveLength(1);
      expect(wrapper.emitted('range-input')[0][0]).toBe(value);
    });
  });
});
