import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import CoverageFuzzingScanner from 'ee/security_orchestration/components/policy_editor/scan_result/rule/scanners/coverage_fuzzing_scanner.vue';
import BaseSeverityStatusScanner from 'ee/security_orchestration/components/policy_editor/scan_result/rule/scanners/base_severity_status_scanner.vue';

describe('CoverageFuzzingScanner', () => {
  let wrapper;

  const defaultRule = {
    type: 'scan_finding',
    branches: [],
    scanners: ['coverage_fuzzing'],
    vulnerabilities_allowed: 0,
    severity_levels: [],
    vulnerability_states: [],
  };

  const createComponent = (scanner = defaultRule, options = {}) => {
    wrapper = shallowMountExtended(CoverageFuzzingScanner, {
      propsData: {
        scanner,
        ...options,
      },
      provide: {
        namespaceType: 'project',
      },
    });
  };

  const findBaseSeverityStatusScanner = () => wrapper.findComponent(BaseSeverityStatusScanner);

  describe('rendering', () => {
    it('renders BaseSeverityStatusScanner with correct props', () => {
      createComponent();

      expect(findBaseSeverityStatusScanner().exists()).toBe(true);
      expect(findBaseSeverityStatusScanner().props('title')).toBe('Coverage Fuzzing Scanning Rule');
      expect(findBaseSeverityStatusScanner().props('scanner')).toEqual(defaultRule);
      expect(findBaseSeverityStatusScanner().props('visible')).toBe(true);
    });
  });

  describe('events', () => {
    beforeEach(() => {
      createComponent();
    });

    it('emits changed event when BaseSeverityStatusScanner emits changed', () => {
      const payload = { branches: ['main'] };

      findBaseSeverityStatusScanner().vm.$emit('changed', payload);

      expect(wrapper.emitted('changed')).toHaveLength(1);
      expect(wrapper.emitted('changed')[0][0]).toEqual(payload);
    });
  });

  describe('remove scanner', () => {
    it('emits remove event when BaseSeverityStatusScanner emits remove', () => {
      createComponent();

      findBaseSeverityStatusScanner().vm.$emit('remove');

      expect(wrapper.emitted('remove')).toHaveLength(1);
    });
  });
});
