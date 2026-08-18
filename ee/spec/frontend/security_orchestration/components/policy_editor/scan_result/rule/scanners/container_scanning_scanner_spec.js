import { nextTick } from 'vue';
import { GlCollapse } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import ContainerScanningScanner from 'ee/security_orchestration/components/policy_editor/scan_result/rule/scanners/container_scanning_scanner.vue';
import ScannerHeader from 'ee/security_orchestration/components/policy_editor/scan_result/rule/scanners/scanner_header.vue';
import ExploitSettingsSection from 'ee/security_orchestration/components/policy_editor/scan_result/rule/scanners/exploit_settings_section.vue';
import EnrichmentDataSettings from 'ee/security_orchestration/components/policy_editor/scan_result/rule/scan_filters/enrichment_data_settings.vue';
import AttributeFilters from 'ee/security_orchestration/components/policy_editor/scan_result/rule/scan_filters/attribute_filters.vue';
import ScanFilterSelector from 'ee/security_orchestration/components/policy_editor/scan_filter_selector.vue';
import VulnerabilitiesAllowedSection from 'ee/security_orchestration/components/policy_editor/scan_result/rule/scanners/vulnerabilities_allowed_section.vue';
import MalwareSettings from 'ee/security_orchestration/components/policy_editor/scan_result/rule/scanners/malware_settings.vue';
import {
  FIX_AVAILABLE,
  FALSE_POSITIVE,
  KNOWN_EXPLOITED,
  EPSS_SCORE,
  ATTRIBUTE,
  ENRICHMENT_DATA_UNAVAILABLE,
  ENRICHMENT_DATA_ACTIONS,
  EXPLOIT_SETTINGS,
} from 'ee/security_orchestration/components/policy_editor/scan_result/rule/scan_filters/constants';
import { GREATER_THAN_OPERATOR } from 'ee/security_orchestration/components/policy_editor/constants';
import { DEFAULT_EPSS_VALUE } from 'ee/security_orchestration/components/policy_editor/scan_result/lib/rules';

describe('ContainerScanningScanner', () => {
  let wrapper;

  const defaultRule = {
    type: 'scan_finding',
    branches: [],
    scanners: ['container_scanning'],
    vulnerabilities_allowed: 0,
    severity_levels: [],
    vulnerability_states: [],
  };

  const defaultExploitAttributes = {
    [KNOWN_EXPLOITED]: true,
    [EPSS_SCORE]: { operator: GREATER_THAN_OPERATOR, value: DEFAULT_EPSS_VALUE },
  };

  const ruleWithExploitSettings = {
    ...defaultRule,
    vulnerability_attributes: { ...defaultExploitAttributes },
  };

  const createComponent = (scanner = defaultRule, options = {}) => {
    const { glFeatures = {}, provide = {}, ...propsOptions } = options;
    wrapper = shallowMountExtended(ContainerScanningScanner, {
      propsData: {
        scanner,
        ...propsOptions,
      },
      provide: {
        glFeatures,
        ...provide,
      },
    });
  };

  const findCollapse = () => wrapper.findComponent(GlCollapse);
  const findScannerHeader = () => wrapper.findComponent(ScannerHeader);
  const findExploitSettingsSection = () => wrapper.findComponent(ExploitSettingsSection);
  const findEnrichmentDataSettings = () => wrapper.findComponent(EnrichmentDataSettings);
  const findAttributeFilters = () => wrapper.findComponent(AttributeFilters);
  const findFilterSelector = () => wrapper.findComponent(ScanFilterSelector);
  const findVulnerabilitiesAllowedSection = () =>
    wrapper.findComponent(VulnerabilitiesAllowedSection);
  const findMalwareSettings = () => wrapper.findComponent(MalwareSettings);

  describe('rendering', () => {
    it('renders collapse component', () => {
      createComponent();

      expect(findCollapse().exists()).toBe(true);
    });

    it('renders scanner header', () => {
      createComponent();

      expect(findScannerHeader().exists()).toBe(true);
    });

    it('renders exploit settings section when scanner has KEV/EPSS', () => {
      createComponent(ruleWithExploitSettings);

      expect(findExploitSettingsSection().exists()).toBe(true);
    });

    it('does not render exploit settings section when scanner has no KEV/EPSS', () => {
      createComponent();

      expect(findExploitSettingsSection().exists()).toBe(false);
    });

    it('renders enrichment data settings', () => {
      createComponent();

      expect(findEnrichmentDataSettings().exists()).toBe(true);
    });

    it('renders attribute filters with default values', () => {
      createComponent();

      expect(findAttributeFilters().exists()).toBe(true);
      expect(findAttributeFilters().props('selected')).toEqual({
        [FIX_AVAILABLE]: true,
        [FALSE_POSITIVE]: false,
      });
    });

    it('renders scan filter selector', () => {
      createComponent();

      expect(findFilterSelector().exists()).toBe(true);
    });
  });

  describe('default attribute filters', () => {
    it('has both attribute filters selected by default', () => {
      createComponent();

      expect(findAttributeFilters().exists()).toBe(true);
      expect(findAttributeFilters().props('selected')).toEqual({
        [FIX_AVAILABLE]: true,
        [FALSE_POSITIVE]: false,
      });
    });
  });

  describe('phantom defaults do not leak into emitted policy data', () => {
    it('does not inject phantom attributes when removing a default attribute from a scanner with only KEV/EPSS', () => {
      // Scanner has KEV and EPSS but no explicit fix_available/false_positive.
      // The UI shows defaults via SCANNER_DEFAULT_ATTRIBUTES — removing one
      // must NOT inject the other as a new attribute into the emitted data.
      createComponent({
        ...defaultRule,
        vulnerability_attributes: {
          [KNOWN_EXPLOITED]: true,
          [EPSS_SCORE]: { operator: GREATER_THAN_OPERATOR, value: 0.5 },
        },
      });

      findAttributeFilters().vm.$emit('remove', FIX_AVAILABLE);

      expect(wrapper.emitted('changed')).toHaveLength(1);
      const emitted = wrapper.emitted('changed')[0][0].vulnerability_attributes;
      // Should preserve KEV and EPSS, include the remaining default (false_positive),
      // but NOT inject fix_available since the user explicitly removed it
      expect(emitted).toHaveProperty(KNOWN_EXPLOITED);
      expect(emitted).toHaveProperty(EPSS_SCORE);
      expect(emitted).toHaveProperty(FALSE_POSITIVE);
      expect(emitted).not.toHaveProperty(FIX_AVAILABLE);
    });

    it('preserves EPSS value of 0 when setVulnerabilityAttributes runs', () => {
      // EPSS value 0 is valid ("flag all vulnerabilities"). It must not be
      // silently dropped by a falsy check in setVulnerabilityAttributes.
      createComponent({
        ...defaultRule,
        vulnerability_attributes: {
          [KNOWN_EXPLOITED]: true,
          [EPSS_SCORE]: { operator: GREATER_THAN_OPERATOR, value: 0 },
          [FIX_AVAILABLE]: true,
        },
      });

      // Trigger setVulnerabilityAttributes via removing an attribute filter
      findAttributeFilters().vm.$emit('remove', FIX_AVAILABLE);

      expect(wrapper.emitted('changed')).toHaveLength(1);
      const emitted = wrapper.emitted('changed')[0][0].vulnerability_attributes;
      expect(emitted[EPSS_SCORE]).toEqual({ operator: GREATER_THAN_OPERATOR, value: 0 });
    });
  });

  describe('KEV and EPSS defaults are not injected on unrelated edits', () => {
    it('does not include KEV/EPSS in emitted data when scanner has no explicit vulnerability_attributes', () => {
      createComponent();

      findFilterSelector().vm.$emit('select', ATTRIBUTE);

      expect(wrapper.emitted('changed')).toHaveLength(1);
      const emitted = wrapper.emitted('changed')[0][0].vulnerability_attributes;
      expect(emitted).not.toHaveProperty(KNOWN_EXPLOITED);
      expect(emitted).not.toHaveProperty(EPSS_SCORE);
    });
  });

  describe('exploit settings section', () => {
    it('renders the section with values from the scanner when KEV/EPSS are present', () => {
      createComponent(ruleWithExploitSettings);

      expect(findExploitSettingsSection().exists()).toBe(true);
      expect(findExploitSettingsSection().props('kevFilterValue')).toBe(true);
      expect(findExploitSettingsSection().props('epssOperator')).toBe(GREATER_THAN_OPERATOR);
      expect(findExploitSettingsSection().props('epssValue')).toBe(DEFAULT_EPSS_VALUE);
    });

    it('preserves EPSS value of 0 instead of falling back to default', () => {
      createComponent({
        ...defaultRule,
        vulnerability_attributes: {
          [EPSS_SCORE]: { operator: GREATER_THAN_OPERATOR, value: 0 },
        },
      });

      expect(findExploitSettingsSection().props('epssValue')).toBe(0);
    });
  });

  describe('visibility prop', () => {
    it('is visible by default', () => {
      createComponent();

      expect(wrapper.props('visible')).toBe(true);
    });

    it('can be initialized as hidden', () => {
      createComponent(defaultRule, { visible: false });

      expect(wrapper.props('visible')).toBe(false);
    });
  });

  describe('existing rule', () => {
    const ruleWithValues = {
      ...defaultRule,
      vulnerabilities_allowed: 5,
      branch_exceptions: ['main'],
      vulnerability_attributes: {
        [KNOWN_EXPLOITED]: true,
        [EPSS_SCORE]: { operator: 'greater_than', value: 0.5 },
        [FIX_AVAILABLE]: false,
        [FALSE_POSITIVE]: true,
      },
    };

    beforeEach(() => {
      createComponent(ruleWithValues);
    });

    it('passes KEV filter value to exploit settings section', () => {
      expect(findExploitSettingsSection().props('kevFilterValue')).toBe(true);
    });

    it('passes EPSS filter values to exploit settings section', () => {
      expect(findExploitSettingsSection().props('epssOperator')).toBe('greater_than');
      expect(findExploitSettingsSection().props('epssValue')).toBe(0.5);
    });

    it('renders attribute filters when attributes are selected', () => {
      expect(findAttributeFilters().exists()).toBe(true);
      expect(findAttributeFilters().props('selected')).toEqual({
        [FIX_AVAILABLE]: false,
        [FALSE_POSITIVE]: true,
      });
    });
  });

  describe('events', () => {
    it('emits changed event when KEV filter changes', () => {
      createComponent(ruleWithExploitSettings);

      findExploitSettingsSection().vm.$emit('kev-change', true);

      expect(wrapper.emitted('changed')).toHaveLength(1);
      expect(wrapper.emitted('changed')[0][0]).toHaveProperty('vulnerability_attributes');
      expect(wrapper.emitted('changed')[0][0].vulnerability_attributes).toHaveProperty(
        KNOWN_EXPLOITED,
        true,
      );
    });

    it('emits changed event when EPSS filter changes', () => {
      createComponent(ruleWithExploitSettings);
      const epssValue = { operator: 'less_than', value: 0.3 };

      findExploitSettingsSection().vm.$emit('epss-change', epssValue);

      expect(wrapper.emitted('changed')).toHaveLength(1);
      expect(wrapper.emitted('changed')[0][0]).toHaveProperty('vulnerability_attributes');
      expect(wrapper.emitted('changed')[0][0].vulnerability_attributes).toHaveProperty(
        EPSS_SCORE,
        epssValue,
      );
    });

    describe('attribute filters', () => {
      beforeEach(() => {
        createComponent();
      });

      it('emits changed event when attribute filters change', () => {
        const payload = { [FIX_AVAILABLE]: true, [FALSE_POSITIVE]: false };

        findAttributeFilters().vm.$emit('input', payload);

        expect(wrapper.emitted('changed')).toHaveLength(1);
        expect(wrapper.emitted('changed')[0][0]).toHaveProperty('vulnerability_attributes');
      });

      it('removes attribute filter when remove is triggered', () => {
        findAttributeFilters().vm.$emit('remove', FIX_AVAILABLE);

        expect(wrapper.emitted('changed')).toHaveLength(1);
      });
    });
  });

  describe('exploit settings remove and re-add', () => {
    it('emits scanner without KEV/EPSS when exploit settings is removed', () => {
      createComponent(ruleWithExploitSettings);

      findExploitSettingsSection().vm.$emit('remove');

      expect(wrapper.emitted('changed')).toHaveLength(1);
      const payload = wrapper.emitted('changed')[0][0];
      expect(payload).not.toHaveProperty('vulnerability_attributes');
    });

    it('preserves other vulnerability_attributes when removing exploit settings', () => {
      createComponent({
        ...defaultRule,
        vulnerability_attributes: {
          ...defaultExploitAttributes,
          [FIX_AVAILABLE]: true,
        },
      });

      findExploitSettingsSection().vm.$emit('remove');

      expect(wrapper.emitted('changed')).toHaveLength(1);
      const emitted = wrapper.emitted('changed')[0][0].vulnerability_attributes;
      expect(emitted).not.toHaveProperty(KNOWN_EXPLOITED);
      expect(emitted).not.toHaveProperty(EPSS_SCORE);
      expect(emitted).toHaveProperty(FIX_AVAILABLE, true);
    });

    it('re-adds default KEV/EPSS when filter selector emits EXPLOIT_SETTINGS', () => {
      createComponent();

      findFilterSelector().vm.$emit('select', EXPLOIT_SETTINGS);

      expect(wrapper.emitted('changed')).toHaveLength(1);
      const emitted = wrapper.emitted('changed')[0][0].vulnerability_attributes;
      expect(emitted).toHaveProperty(KNOWN_EXPLOITED, true);
      expect(emitted).toHaveProperty(EPSS_SCORE, {
        operator: GREATER_THAN_OPERATOR,
        value: DEFAULT_EPSS_VALUE,
      });
    });

    it('marks EXPLOIT_SETTINGS as selected in the filter state when section is visible', () => {
      createComponent(ruleWithExploitSettings);

      expect(findFilterSelector().props('selected')[EXPLOIT_SETTINGS]).toBe(true);
    });

    it('marks EXPLOIT_SETTINGS as not selected in the filter state when section is hidden', () => {
      createComponent();

      expect(findFilterSelector().props('selected')[EXPLOIT_SETTINGS]).toBe(false);
    });
  });

  describe('selecting filter', () => {
    it('adds the opposite attribute when one is already selected', () => {
      createComponent({
        ...defaultRule,
        vulnerability_attributes: {
          [FIX_AVAILABLE]: true,
        },
      });

      findFilterSelector().vm.$emit('select');

      expect(wrapper.emitted('changed')).toHaveLength(1);
      expect(wrapper.emitted('changed')[0][0].vulnerability_attributes).toHaveProperty(
        FALSE_POSITIVE,
        true,
      );
    });
  });

  describe('filter selector disabled state', () => {
    it('is disabled by default with both attributes selected', () => {
      createComponent();

      expect(findFilterSelector().props('shouldDisableFilter')(ATTRIBUTE)).toBe(true);
    });

    it('is not disabled when one attribute is selected', () => {
      createComponent({
        ...defaultRule,
        vulnerability_attributes: {
          [FIX_AVAILABLE]: true,
        },
      });

      expect(findFilterSelector().props('shouldDisableFilter')(ATTRIBUTE)).toBe(false);
    });
  });

  describe('scan filter selector', () => {
    it('passes correct filter state with default attributes', () => {
      createComponent();

      expect(findFilterSelector().props('selected')).toEqual({
        [FIX_AVAILABLE]: true,
        [FALSE_POSITIVE]: true,
        [ATTRIBUTE]: true,
        [EXPLOIT_SETTINGS]: false,
      });
    });

    it('passes correct filter state when one attribute is selected', () => {
      createComponent({
        ...defaultRule,
        vulnerability_attributes: {
          [FIX_AVAILABLE]: true,
        },
      });

      expect(findFilterSelector().props('selected')).toEqual({
        [FIX_AVAILABLE]: true,
        [FALSE_POSITIVE]: false,
        [ATTRIBUTE]: false,
        [EXPLOIT_SETTINGS]: false,
      });
    });
  });

  describe('collapse behavior', () => {
    it('toggles collapse when header emits toggle', async () => {
      createComponent();

      expect(findCollapse().props('visible')).toBe(true);

      findScannerHeader().vm.$emit('toggle');
      await nextTick();

      expect(findCollapse().props('visible')).toBe(false);
    });
  });

  describe('vulnerabilities allowed section', () => {
    it('renders VulnerabilitiesAllowedSection component', () => {
      createComponent();

      expect(findVulnerabilitiesAllowedSection().exists()).toBe(true);
    });

    it('passes correct vulnerabilitiesAllowed value from scanner prop', () => {
      createComponent({ ...defaultRule, vulnerabilities_allowed: 5 });

      expect(findVulnerabilitiesAllowedSection().props('vulnerabilitiesAllowed')).toBe(5);
    });

    it('emits changed with updated vulnerabilities_allowed when input changes', () => {
      createComponent();

      findVulnerabilitiesAllowedSection().vm.$emit('input', 3);

      expect(wrapper.emitted('changed')).toHaveLength(1);
      expect(wrapper.emitted('changed')[0][0]).toMatchObject({
        vulnerabilities_allowed: 3,
      });
    });
  });

  describe('remove scanner', () => {
    it('passes showRemoveButton prop to scanner header', () => {
      createComponent();

      expect(findScannerHeader().props('showRemoveButton')).toBe(true);
    });

    it('emits remove event when scanner header emits remove', () => {
      createComponent();

      findScannerHeader().vm.$emit('remove');

      expect(wrapper.emitted('remove')).toHaveLength(1);
    });
  });

  describe('enrichment data settings', () => {
    it('renders enrichment data settings with default block action', () => {
      createComponent();

      expect(findEnrichmentDataSettings().exists()).toBe(true);
      expect(findEnrichmentDataSettings().props('selectedAction')).toBe(
        ENRICHMENT_DATA_ACTIONS.BLOCK,
      );
    });

    it('loads saved enrichment_data_unavailable action from scanner', () => {
      createComponent({
        ...defaultRule,
        vulnerability_attributes: {
          [KNOWN_EXPLOITED]: true,
          [EPSS_SCORE]: { operator: GREATER_THAN_OPERATOR, value: 0.5 },
          [ENRICHMENT_DATA_UNAVAILABLE]: { action: ENRICHMENT_DATA_ACTIONS.IGNORE },
        },
      });

      expect(findEnrichmentDataSettings().props('selectedAction')).toBe(
        ENRICHMENT_DATA_ACTIONS.IGNORE,
      );
    });

    it('emits changed event with updated enrichment_data_unavailable when action changes', () => {
      createComponent({
        ...defaultRule,
        vulnerability_attributes: {
          [KNOWN_EXPLOITED]: true,
          [EPSS_SCORE]: { operator: GREATER_THAN_OPERATOR, value: 0.5 },
          [FIX_AVAILABLE]: true,
        },
      });

      findEnrichmentDataSettings().vm.$emit('change', ENRICHMENT_DATA_ACTIONS.IGNORE);

      expect(wrapper.emitted('changed')).toHaveLength(1);
      const emitted = wrapper.emitted('changed')[0][0].vulnerability_attributes;
      expect(emitted).toHaveProperty(ENRICHMENT_DATA_UNAVAILABLE, {
        action: ENRICHMENT_DATA_ACTIONS.IGNORE,
      });
      // Should also preserve other attributes
      expect(emitted).toHaveProperty(KNOWN_EXPLOITED);
      expect(emitted).toHaveProperty(EPSS_SCORE);
      expect(emitted).toHaveProperty(FIX_AVAILABLE);
    });

    it('preserves enrichment_data_unavailable when editing other attributes', () => {
      createComponent({
        ...defaultRule,
        vulnerability_attributes: {
          [KNOWN_EXPLOITED]: true,
          [EPSS_SCORE]: { operator: GREATER_THAN_OPERATOR, value: 0.5 },
          [FIX_AVAILABLE]: true,
          [ENRICHMENT_DATA_UNAVAILABLE]: { action: ENRICHMENT_DATA_ACTIONS.IGNORE },
        },
      });

      findAttributeFilters().vm.$emit('remove', FIX_AVAILABLE);

      expect(wrapper.emitted('changed')).toHaveLength(1);
      const emitted = wrapper.emitted('changed')[0][0].vulnerability_attributes;
      expect(emitted).toHaveProperty(ENRICHMENT_DATA_UNAVAILABLE, {
        action: ENRICHMENT_DATA_ACTIONS.IGNORE,
      });
    });
  });

  describe('malware settings', () => {
    const enabled = {
      glFeatures: { securityPoliciesMalwareAttribute: true },
    };

    describe('visibility', () => {
      it('renders the control when the feature flag is enabled', () => {
        createComponent(defaultRule, enabled);

        expect(findMalwareSettings().exists()).toBe(true);
      });

      it('hides the control when the feature flag is off', () => {
        createComponent(defaultRule, {
          glFeatures: { securityPoliciesMalwareAttribute: false },
        });

        expect(findMalwareSettings().exists()).toBe(false);
      });

      it('hides the control by default when nothing is provided', () => {
        createComponent();

        expect(findMalwareSettings().exists()).toBe(false);
      });
    });

    describe('value', () => {
      it('passes value=false when scanner has no is_malicious', () => {
        createComponent(defaultRule, enabled);

        expect(findMalwareSettings().props('value')).toBe(false);
      });

      it('passes value=true when scanner has is_malicious set', () => {
        createComponent({ ...defaultRule, is_malicious: true }, enabled);

        expect(findMalwareSettings().props('value')).toBe(true);
      });
    });

    describe('events', () => {
      it('adds is_malicious to the scanner when toggled on', () => {
        createComponent(defaultRule, enabled);

        findMalwareSettings().vm.$emit('input', true);

        expect(wrapper.emitted('changed')).toHaveLength(1);
        expect(wrapper.emitted('changed')[0][0]).toHaveProperty('is_malicious', true);
      });

      it('sets is_malicious to false when toggled off', () => {
        createComponent({ ...defaultRule, is_malicious: true }, enabled);

        findMalwareSettings().vm.$emit('input', false);

        expect(wrapper.emitted('changed')).toHaveLength(1);
        expect(wrapper.emitted('changed')[0][0]).toHaveProperty('is_malicious', false);
      });
    });
  });
});
