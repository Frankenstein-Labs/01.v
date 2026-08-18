import { GlSprintf } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import SecurityScanRuleBuilder from 'ee/security_orchestration/components/policy_editor/scan_result/rule/security_scan_rule_builder.vue';
import { REPORT_TYPES_DEFAULT } from 'ee/security_dashboard/constants';
import {
  RECOMMENDED_SCANNERS_KEY,
  DEFAULT_SCANNERS,
  buildDefaultScannerObject,
} from 'ee/security_orchestration/components/policy_editor/scan_result/lib/rules';

import ScanTypeSelect from 'ee/security_orchestration/components/policy_editor/scan_result/rule/scan_type_select.vue';
import RuleMultiSelect from 'ee/security_orchestration/components/policy_editor/rule_multi_select.vue';
import BranchSelection from 'ee/security_orchestration/components/policy_editor/branch_selection.vue';
import BranchExceptionSelector from 'ee/security_orchestration/components/policy_editor/branch_exception_selector.vue';
import NumberRangeSelect from 'ee/security_orchestration/components/policy_editor/scan_result/rule/number_range_select.vue';
import GlobalSettings from 'ee/security_orchestration/components/policy_editor/scan_result/rule/scanners/global_settings.vue';
import DependencyScanner from 'ee/security_orchestration/components/policy_editor/scan_result/rule/scanners/dependency_scanner.vue';
import SastScanner from 'ee/security_orchestration/components/policy_editor/scan_result/rule/scanners/sast_scanner.vue';
import SecretDetectionScanner from 'ee/security_orchestration/components/policy_editor/scan_result/rule/scanners/secret_detection_scanner.vue';
import ContainerScanningScanner from 'ee/security_orchestration/components/policy_editor/scan_result/rule/scanners/container_scanning_scanner.vue';
import DastScanner from 'ee/security_orchestration/components/policy_editor/scan_result/rule/scanners/dast_scanner.vue';
import ApiFuzzingScanner from 'ee/security_orchestration/components/policy_editor/scan_result/rule/scanners/api_fuzzing_scanner.vue';
import CoverageFuzzingScanner from 'ee/security_orchestration/components/policy_editor/scan_result/rule/scanners/coverage_fuzzing_scanner.vue';

describe('SecurityScanRuleBuilder', () => {
  let wrapper;

  const allScanners = [
    'sast',
    'secret_detection',
    'dependency_scanning',
    'container_scanning',
    'dast',
    'api_fuzzing',
    'coverage_fuzzing',
  ];

  const allScannerObjects = allScanners.map(buildDefaultScannerObject);

  const defaultRule = {
    type: 'scan_finding',
    scanners: allScannerObjects,
    vulnerabilities_allowed: 0,
    branch_exceptions: [],
  };

  const createComponent = ({ initRule = defaultRule } = {}) => {
    wrapper = shallowMountExtended(SecurityScanRuleBuilder, {
      propsData: {
        initRule,
      },
      provide: {
        namespaceType: 'project',
      },
      stubs: {
        GlSprintf,
      },
    });
  };

  const findScanTypeSelect = () => wrapper.findComponent(ScanTypeSelect);
  const findScannersSelect = () => wrapper.findComponent(RuleMultiSelect);
  const findBranchSelection = () => wrapper.findComponent(BranchSelection);
  const findBranchExceptionSelector = () => wrapper.findComponent(BranchExceptionSelector);
  const findNumberRangeSelect = () => wrapper.findComponent(NumberRangeSelect);
  const findGlobalSettings = () => wrapper.findComponent(GlobalSettings);
  const findDependencyScanner = () => wrapper.findComponent(DependencyScanner);
  const findSastScanner = () => wrapper.findComponent(SastScanner);
  const findSecretDetectionScanner = () => wrapper.findComponent(SecretDetectionScanner);
  const findContainerScanningScanner = () => wrapper.findComponent(ContainerScanningScanner);
  const findDastScanner = () => wrapper.findComponent(DastScanner);
  const findApiFuzzingScanner = () => wrapper.findComponent(ApiFuzzingScanner);
  const findCoverageFuzzingScanner = () => wrapper.findComponent(CoverageFuzzingScanner);

  describe('rendering', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders scan type select', () => {
      expect(findScanTypeSelect().exists()).toBe(true);
    });

    it('renders scanners multi select', () => {
      expect(findScannersSelect().exists()).toBe(true);
    });

    it('renders branch selection', () => {
      expect(findBranchSelection().exists()).toBe(true);
    });

    it('renders branch exception selector', () => {
      expect(findBranchExceptionSelector().exists()).toBe(true);
    });

    it('renders vulnerabilities number selector', () => {
      expect(findNumberRangeSelect().exists()).toBe(true);
    });

    it('renders global settings with scanner prop', () => {
      expect(findGlobalSettings().exists()).toBe(true);
      expect(findGlobalSettings().props('scanner')).toEqual(defaultRule);
    });

    it('renders dependency scanner with scanner prop', () => {
      expect(findDependencyScanner().exists()).toBe(true);
      expect(findDependencyScanner().props('scanner')).toMatchObject({
        type: 'dependency_scanning',
        vulnerabilities_allowed: 0,
      });
    });

    it('renders sast scanner with scanner prop', () => {
      expect(findSastScanner().exists()).toBe(true);
      expect(findSastScanner().props('scanner')).toMatchObject({
        type: 'sast',
        vulnerabilities_allowed: 0,
      });
    });

    it('renders secret detection scanner with scanner prop', () => {
      expect(findSecretDetectionScanner().exists()).toBe(true);
      expect(findSecretDetectionScanner().props('scanner')).toMatchObject({
        type: 'secret_detection',
        vulnerabilities_allowed: 0,
      });
    });

    it('renders container scanning scanner with scanner prop', () => {
      expect(findContainerScanningScanner().exists()).toBe(true);
      expect(findContainerScanningScanner().props('scanner')).toMatchObject({
        type: 'container_scanning',
        vulnerabilities_allowed: 0,
      });
    });

    it('renders dast scanner with scanner prop', () => {
      expect(findDastScanner().exists()).toBe(true);
      expect(findDastScanner().props('scanner')).toMatchObject({
        type: 'dast',
        vulnerabilities_allowed: 0,
      });
    });

    it('renders api fuzzing scanner with scanner prop', () => {
      expect(findApiFuzzingScanner().exists()).toBe(true);
      expect(findApiFuzzingScanner().props('scanner')).toMatchObject({
        type: 'api_fuzzing',
        vulnerabilities_allowed: 0,
      });
    });

    it('renders coverage fuzzing scanner with scanner prop', () => {
      expect(findCoverageFuzzingScanner().exists()).toBe(true);
      expect(findCoverageFuzzingScanner().props('scanner')).toMatchObject({
        type: 'coverage_fuzzing',
        vulnerabilities_allowed: 0,
      });
    });
  });

  describe('legacy string scanner conversion', () => {
    it('converts string scanners to objects without leaking rule-level fields', () => {
      const legacyRule = {
        type: 'scan_finding',
        scanners: ['sast', 'dependency_scanning'],
        vulnerabilities_allowed: 2,
        severity_levels: ['critical'],
        vulnerability_states: ['detected'],
        vulnerability_attributes: {
          false_positive: false,
          fix_available: true,
          known_exploited: true,
          epss_score: { operator: 'greater_than', value: 0.5 },
        },
        branch_type: 'protected',
        branch_exceptions: ['main'],
      };

      createComponent({ initRule: legacyRule });

      const sastScanner = findSastScanner().props('scanner');
      expect(sastScanner.type).toBe('sast');
      expect(sastScanner.vulnerabilities_allowed).toBe(2);
      expect(sastScanner.severity_levels).toEqual(['critical']);
      expect(sastScanner.vulnerability_states).toEqual(['detected']);
      expect(sastScanner.vulnerability_attributes).toEqual({
        false_positive: false,
        fix_available: true,
        known_exploited: true,
        epss_score: { operator: 'greater_than', value: 0.5 },
      });
      expect(sastScanner.branch_type).toBeUndefined();
      expect(sastScanner.branch_exceptions).toBeUndefined();
    });
  });

  describe('scanner visibility', () => {
    it('all scanners are collapsed by default', () => {
      createComponent();

      expect(findDependencyScanner().props('visible')).toBe(false);
      expect(findSastScanner().props('visible')).toBe(false);
      expect(findSecretDetectionScanner().props('visible')).toBe(false);
      expect(findContainerScanningScanner().props('visible')).toBe(false);
      expect(findDastScanner().props('visible')).toBe(false);
      expect(findApiFuzzingScanner().props('visible')).toBe(false);
      expect(findCoverageFuzzingScanner().props('visible')).toBe(false);
    });
  });

  describe('scanner default configuration', () => {
    it('passes isDefaultConfiguration as true for default scanner objects', () => {
      createComponent();

      expect(findDependencyScanner().props('isDefaultConfiguration')).toBe(true);
      expect(findSastScanner().props('isDefaultConfiguration')).toBe(true);
      expect(findSecretDetectionScanner().props('isDefaultConfiguration')).toBe(true);
    });

    it('passes showDefaultRuleBadge as true for default scanner types', () => {
      createComponent();

      expect(findDependencyScanner().props('showDefaultRuleBadge')).toBe(true);
      expect(findSastScanner().props('showDefaultRuleBadge')).toBe(true);
      expect(findSecretDetectionScanner().props('showDefaultRuleBadge')).toBe(true);
    });

    it('does not pass showDefaultRuleBadge to non-default scanners', () => {
      createComponent();

      expect(findContainerScanningScanner().props('showDefaultRuleBadge')).toBeUndefined();
      expect(findDastScanner().props('showDefaultRuleBadge')).toBeUndefined();
      expect(findApiFuzzingScanner().props('showDefaultRuleBadge')).toBeUndefined();
      expect(findCoverageFuzzingScanner().props('showDefaultRuleBadge')).toBeUndefined();
    });

    it('does not pass isDefaultConfiguration to non-default scanners', () => {
      createComponent();

      expect(findContainerScanningScanner().props('isDefaultConfiguration')).toBeUndefined();
      expect(findDastScanner().props('isDefaultConfiguration')).toBeUndefined();
      expect(findApiFuzzingScanner().props('isDefaultConfiguration')).toBeUndefined();
      expect(findCoverageFuzzingScanner().props('isDefaultConfiguration')).toBeUndefined();
    });

    it('passes isDefaultConfiguration as false when scanner is modified', () => {
      const modifiedScanners = allScannerObjects.map((s) =>
        s.type === 'sast' ? { ...s, severity_levels: ['critical'] } : s,
      );

      createComponent({
        initRule: { ...defaultRule, scanners: modifiedScanners },
      });

      expect(findSastScanner().props('isDefaultConfiguration')).toBe(false);
      expect(findDependencyScanner().props('isDefaultConfiguration')).toBe(true);
      expect(findSecretDetectionScanner().props('isDefaultConfiguration')).toBe(true);
    });

    it.each`
      scannerName           | scannerType              | findMethod
      ${'sast'}             | ${'sast'}                | ${() => findSastScanner()}
      ${'dependency'}       | ${'dependency_scanning'} | ${() => findDependencyScanner()}
      ${'secret detection'} | ${'secret_detection'}    | ${() => findSecretDetectionScanner()}
    `(
      'resets $scannerName scanner to default when reset event is emitted',
      ({ scannerType, findMethod }) => {
        const modifiedScanners = allScannerObjects.map((s) =>
          s.type === scannerType ? { ...s, severity_levels: ['critical'] } : s,
        );

        createComponent({
          initRule: { ...defaultRule, scanners: modifiedScanners },
        });

        findMethod().vm.$emit('reset');

        const emittedRule = wrapper.emitted('changed')[0][0];
        const scanner = emittedRule.scanners.find((s) => s.type === scannerType);
        expect(scanner).toEqual(buildDefaultScannerObject(scannerType));
      },
    );
  });

  describe('scanners toggle text', () => {
    it('passes recommended toggle text when recommended scanners are selected', () => {
      createComponent({
        initRule: { ...defaultRule, scanners: DEFAULT_SCANNERS },
      });

      expect(findScannersSelect().props('toggleTextOverride')).toBe('Recommended (3 scanners)');
    });

    it('passes empty toggle text when non-recommended scanners are selected', () => {
      createComponent({
        initRule: { ...defaultRule, scanners: [buildDefaultScannerObject('sast')] },
      });

      expect(findScannersSelect().props('toggleTextOverride')).toBe('');
    });

    it('passes empty toggle text when all scanners are selected', () => {
      createComponent();

      expect(findScannersSelect().props('toggleTextOverride')).toBe('');
    });
  });

  describe('selected values', () => {
    it('returns empty scanner keys when scanners array is empty', () => {
      createComponent({
        initRule: {
          ...defaultRule,
          scanners: [],
        },
      });

      expect(findScannersSelect().props('value')).toEqual([]);
    });

    it('returns all scanner keys when all are selected', () => {
      createComponent();

      expect(findScannersSelect().props('value')).toEqual(allScanners);
    });

    it('includes recommended key when recommended scanners are selected', () => {
      const recommendedScanners = DEFAULT_SCANNERS.map((s) => ({ ...s }));

      createComponent({
        initRule: {
          ...defaultRule,
          scanners: recommendedScanners,
        },
      });

      expect(findScannersSelect().props('value')).toContain(RECOMMENDED_SCANNERS_KEY);
    });

    it('returns selected scanner keys when provided as objects', () => {
      const scanners = [
        { type: 'sast', vulnerabilities_allowed: 0, severity_levels: [], vulnerability_states: [] },
        {
          type: 'dependency_scanning',
          vulnerabilities_allowed: 0,
          severity_levels: [],
          vulnerability_states: [],
        },
      ];

      createComponent({
        initRule: {
          ...defaultRule,
          scanners,
        },
      });

      expect(findScannersSelect().props('value')).toEqual(['sast', 'dependency_scanning']);
    });

    it('passes dropdown items with recommended option', () => {
      createComponent();

      expect(findScannersSelect().props('items')).toEqual({
        [RECOMMENDED_SCANNERS_KEY]: expect.stringContaining('Recommended'),
        ...REPORT_TYPES_DEFAULT,
      });
    });

    it('renders existing branch types', () => {
      const newRule = {
        ...defaultRule,
        branchType: 'default',
      };

      createComponent({ initRule: newRule });

      expect(findBranchSelection().props('initRule')).toEqual(newRule);
    });
  });

  describe('events', () => {
    beforeEach(() => {
      createComponent();
    });

    it('emits set-scan-type when scan type changes', () => {
      const newRule = { type: 'license_finding' };

      findScanTypeSelect().vm.$emit('select', 'license_finding');

      expect(wrapper.emitted('set-scan-type')).toHaveLength(1);
      expect(wrapper.emitted('set-scan-type')[0][0]).toMatchObject(newRule);
    });

    it('sets recommended scanners when recommended is selected', () => {
      createComponent({
        initRule: {
          ...defaultRule,
          scanners: [
            {
              type: 'sast',
              vulnerabilities_allowed: 0,
              severity_levels: [],
              vulnerability_states: [],
            },
          ],
        },
      });

      findScannersSelect().vm.$emit('input', [RECOMMENDED_SCANNERS_KEY, 'sast']);

      const emittedRule = wrapper.emitted('changed')[0][0];
      expect(emittedRule.scanners).toEqual(DEFAULT_SCANNERS);
    });

    it('selects all scanners when select all is triggered including recommended key', () => {
      createComponent({
        initRule: {
          ...defaultRule,
          scanners: [
            {
              type: 'sast',
              vulnerabilities_allowed: 0,
              severity_levels: [],
              vulnerability_states: [],
            },
          ],
        },
      });

      const allKeysIncludingRecommended = [RECOMMENDED_SCANNERS_KEY, ...allScanners];
      findScannersSelect().vm.$emit('input', allKeysIncludingRecommended);

      const emittedRule = wrapper.emitted('changed')[0][0];
      expect(emittedRule.scanners).toHaveLength(allScanners.length);
      expect(emittedRule.scanners.map((s) => s.type)).toEqual(expect.arrayContaining(allScanners));
    });

    it('switches to recommended when recommended is selected and all scanners were active', () => {
      createComponent();

      const allKeysIncludingRecommended = [RECOMMENDED_SCANNERS_KEY, ...allScanners];
      findScannersSelect().vm.$emit('input', allKeysIncludingRecommended);

      const emittedRule = wrapper.emitted('changed')[0][0];
      expect(emittedRule.scanners).toHaveLength(DEFAULT_SCANNERS.length);
      expect(emittedRule.scanners.map((s) => s.type)).toEqual(
        expect.arrayContaining(['sast', 'secret_detection', 'dependency_scanning']),
      );
    });

    it('updates scanners when scanners selection changes', () => {
      const scannerKeys = ['sast'];

      findScannersSelect().vm.$emit('input', scannerKeys);

      const emittedRule = wrapper.emitted('changed')[0][0];
      expect(emittedRule.scanners).toEqual([expect.objectContaining({ type: 'sast' })]);
    });

    it('preserves existing scanner objects when selection changes', () => {
      const modifiedScanners = allScannerObjects.map((s) =>
        s.type === 'sast' ? { ...s, severity_levels: ['critical'] } : s,
      );

      createComponent({
        initRule: { ...defaultRule, scanners: modifiedScanners },
      });

      findScannersSelect().vm.$emit('input', ['sast', 'dast']);

      const emittedRule = wrapper.emitted('changed')[0][0];
      const sastScanner = emittedRule.scanners.find((s) => s.type === 'sast');
      expect(sastScanner.severity_levels).toEqual(['critical']);
    });

    it('creates default scanner object for newly added scanners', () => {
      createComponent({
        initRule: {
          ...defaultRule,
          scanners: [
            {
              type: 'sast',
              vulnerabilities_allowed: 0,
              severity_levels: [],
              vulnerability_states: [],
            },
          ],
        },
      });

      findScannersSelect().vm.$emit('input', ['sast', 'dast']);

      const emittedRule = wrapper.emitted('changed')[0][0];
      const dastScanner = emittedRule.scanners.find((s) => s.type === 'dast');
      expect(dastScanner).toEqual(buildDefaultScannerObject('dast'));
    });

    it('updates vulnerabilities allowed range', () => {
      const value = 5;

      findNumberRangeSelect().vm.$emit('input', value);

      expect(wrapper.emitted('changed')).toEqual([
        [{ ...defaultRule, vulnerabilities_allowed: value }],
      ]);
    });

    it('updates rule when branch selection changes', () => {
      const payload = { branches: ['main'] };

      findBranchSelection().vm.$emit('changed', payload);

      expect(wrapper.emitted('changed')).toEqual([[{ ...defaultRule, ...payload }]]);
    });

    it('removes branch exceptions when remove is triggered', () => {
      createComponent({
        initRule: {
          ...defaultRule,
          branch_exceptions: ['dev'],
        },
      });

      findBranchExceptionSelector().vm.$emit('remove');

      expect(wrapper.emitted('changed')[0][0]).not.toHaveProperty('branch_exceptions');
    });

    it('updates global settings', () => {
      const updatedRule = {
        ...defaultRule,
        severity_levels: ['high'],
      };

      findGlobalSettings().vm.$emit('changed', updatedRule);

      expect(wrapper.emitted('changed')).toEqual([[updatedRule]]);
    });

    it('updates rule when dependency scanner changes', () => {
      const updatedScanner = {
        type: 'dependency_scanning',
        vulnerability_attributes: {
          fix_available: true,
        },
      };

      findDependencyScanner().vm.$emit('changed', updatedScanner);

      const emittedRule = wrapper.emitted('changed')[0][0];
      expect(emittedRule.scanners).toEqual(
        expect.arrayContaining([expect.objectContaining(updatedScanner)]),
      );
    });

    it('updates rule when sast scanner changes', () => {
      const updatedScanner = {
        type: 'sast',
        severity_levels: ['critical', 'high'],
      };

      findSastScanner().vm.$emit('changed', updatedScanner);

      const emittedRule = wrapper.emitted('changed')[0][0];
      expect(emittedRule.scanners).toEqual(
        expect.arrayContaining([expect.objectContaining(updatedScanner)]),
      );
    });

    it('updates rule when secret detection scanner changes', () => {
      const updatedScanner = {
        type: 'secret_detection',
        severity_levels: ['critical', 'high'],
        vulnerability_states: ['new_needs_triage'],
      };

      findSecretDetectionScanner().vm.$emit('changed', updatedScanner);

      const emittedRule = wrapper.emitted('changed')[0][0];
      expect(emittedRule.scanners).toEqual(
        expect.arrayContaining([expect.objectContaining(updatedScanner)]),
      );
    });

    it('updates rule when container scanning scanner changes', () => {
      const updatedScanner = {
        type: 'container_scanning',
        vulnerability_attributes: {
          fix_available: true,
          false_positive: false,
        },
      };

      findContainerScanningScanner().vm.$emit('changed', updatedScanner);

      const emittedRule = wrapper.emitted('changed')[0][0];
      expect(emittedRule.scanners).toEqual(
        expect.arrayContaining([expect.objectContaining(updatedScanner)]),
      );
    });

    it('updates rule when dast scanner changes', () => {
      const updatedScanner = {
        type: 'dast',
        severity_levels: ['critical', 'high'],
      };

      findDastScanner().vm.$emit('changed', updatedScanner);

      const emittedRule = wrapper.emitted('changed')[0][0];
      expect(emittedRule.scanners).toEqual(
        expect.arrayContaining([expect.objectContaining(updatedScanner)]),
      );
    });

    it('updates rule when api fuzzing scanner changes', () => {
      const updatedScanner = {
        type: 'api_fuzzing',
        severity_levels: ['critical', 'high'],
      };

      findApiFuzzingScanner().vm.$emit('changed', updatedScanner);

      const emittedRule = wrapper.emitted('changed')[0][0];
      expect(emittedRule.scanners).toEqual(
        expect.arrayContaining([expect.objectContaining(updatedScanner)]),
      );
    });

    it('updates rule when coverage fuzzing scanner changes', () => {
      const updatedScanner = {
        type: 'coverage_fuzzing',
        severity_levels: ['critical', 'high'],
      };

      findCoverageFuzzingScanner().vm.$emit('changed', updatedScanner);

      const emittedRule = wrapper.emitted('changed')[0][0];
      expect(emittedRule.scanners).toEqual(
        expect.arrayContaining([expect.objectContaining(updatedScanner)]),
      );
    });

    describe('remove scanner', () => {
      it.each`
        scannerName             | scannerType              | findMethod
        ${'dependency'}         | ${'dependency_scanning'} | ${findDependencyScanner}
        ${'sast'}               | ${'sast'}                | ${findSastScanner}
        ${'secret detection'}   | ${'secret_detection'}    | ${findSecretDetectionScanner}
        ${'container scanning'} | ${'container_scanning'}  | ${findContainerScanningScanner}
        ${'dast'}               | ${'dast'}                | ${findDastScanner}
        ${'api fuzzing'}        | ${'api_fuzzing'}         | ${findApiFuzzingScanner}
        ${'coverage fuzzing'}   | ${'coverage_fuzzing'}    | ${findCoverageFuzzingScanner}
      `(
        'removes $scannerName scanner when remove event is emitted',
        ({ scannerType, findMethod }) => {
          createComponent();

          findMethod().vm.$emit('remove');

          const emittedRule = wrapper.emitted('changed')[0][0];
          expect(emittedRule.scanners).not.toEqual(
            expect.arrayContaining([expect.objectContaining({ type: scannerType })]),
          );
        },
      );

      it('emits updated scanners array when a scanner is removed', () => {
        const scanners = [
          {
            type: 'sast',
            vulnerabilities_allowed: 0,
            severity_levels: [],
            vulnerability_states: [],
          },
          {
            type: 'dast',
            vulnerabilities_allowed: 0,
            severity_levels: [],
            vulnerability_states: [],
          },
        ];

        createComponent({
          initRule: {
            ...defaultRule,
            scanners,
          },
        });

        findSastScanner().vm.$emit('remove');

        const emittedRule = wrapper.emitted('changed')[0][0];
        expect(emittedRule.scanners).toEqual([expect.objectContaining({ type: 'dast' })]);
      });
    });
  });
});
