<script>
import { GlCollapse } from '@gitlab/ui';
import { s__ } from '~/locale';
import SectionLayout from 'ee/security_orchestration/components/policy_editor/section_layout.vue';
import ScanFilterSelector from 'ee/security_orchestration/components/policy_editor/scan_filter_selector.vue';
import VulnerabilitiesAllowedSection from 'ee/security_orchestration/components/policy_editor/scan_result/rule/scanners/vulnerabilities_allowed_section.vue';
import AttributeFilters from 'ee/security_orchestration/components/policy_editor/scan_result/rule/scan_filters/attribute_filters.vue';
import {
  KNOWN_EXPLOITED,
  EPSS_SCORE,
  FIX_AVAILABLE,
  FALSE_POSITIVE,
  ATTRIBUTE,
  VULNERABILITY_ATTRIBUTES,
  ENRICHMENT_DATA_UNAVAILABLE,
  EXPLOIT_SETTINGS,
} from 'ee/security_orchestration/components/policy_editor/scan_result/rule/scan_filters/constants';
import { getEnrichmentDataAction } from 'ee/security_orchestration/components/policy_editor/scan_result/rule/scan_filters/utils';
import { GREATER_THAN_OPERATOR } from 'ee/security_orchestration/components/policy_editor/constants';
import { REPORT_TYPE_CONTAINER_SCANNING } from '~/vue_shared/security_reports/constants';
import {
  DEFAULT_EPSS_VALUE,
  SCANNER_DEFAULT_ATTRIBUTES,
} from 'ee/security_orchestration/components/policy_editor/scan_result/lib/rules';
import {
  buildVulnerabilitiesPayload,
  getVulnerabilityAttribute,
} from 'ee/security_orchestration/components/policy_editor/scan_result/rule/utils';
import {
  buildExploitSettingsAttributes,
  buildVulnerabilityAttributes,
  removeExploitSettingsFromScanner,
} from 'ee/security_orchestration/components/policy_editor/scan_result/rule/scanners/utils';

import glFeatureFlagsMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import ScannerHeader from 'ee/security_orchestration/components/policy_editor/scan_result/rule/scanners/scanner_header.vue';
import ExploitSettingsSection from 'ee/security_orchestration/components/policy_editor/scan_result/rule/scanners/exploit_settings_section.vue';
import EnrichmentDataSettings from 'ee/security_orchestration/components/policy_editor/scan_result/rule/scan_filters/enrichment_data_settings.vue';
import MalwareSettings from 'ee/security_orchestration/components/policy_editor/scan_result/rule/scanners/malware_settings.vue';

export default {
  ATTRIBUTE_FILTERS: [
    {
      text: s__('ScanResultPolicy|New attribute'),
      value: ATTRIBUTE,
      tooltip: s__('ScanResultPolicy|Maximum of two attribute criteria allowed'),
    },
    {
      text: s__('ScanResultPolicy|Exploit settings'),
      value: EXPLOIT_SETTINGS,
      tooltip: s__('ScanResultPolicy|Exploit settings are already added'),
    },
  ],
  i18n: {
    title: s__('SecurityOrchestration|Container Scanning Rule'),
  },
  name: 'ContainerScanningScanner',
  components: {
    GlCollapse,
    SectionLayout,
    AttributeFilters,
    ScanFilterSelector,
    ScannerHeader,
    ExploitSettingsSection,
    EnrichmentDataSettings,
    VulnerabilitiesAllowedSection,
    MalwareSettings,
  },
  mixins: [glFeatureFlagsMixin()],
  props: {
    scanner: {
      type: Object,
      required: true,
    },
    visible: {
      type: Boolean,
      required: false,
      default: true,
    },
  },
  emits: ['changed', 'remove'],
  data() {
    return {
      localVisible: this.visible,
    };
  },
  computed: {
    vulnerabilitiesAllowed() {
      return this.scanner.vulnerabilities_allowed || 0;
    },
    isMalicious() {
      return this.scanner.is_malicious === true;
    },
    showMalwareSettings() {
      return Boolean(this.glFeatures?.securityPoliciesMalwareAttribute);
    },
    kevFilterValue() {
      return getVulnerabilityAttribute(this.scanner, KNOWN_EXPLOITED) ?? true;
    },
    epssOperator() {
      return (
        this.scanner?.vulnerability_attributes?.[EPSS_SCORE]?.operator ?? GREATER_THAN_OPERATOR
      );
    },
    epssValue() {
      return this.scanner?.vulnerability_attributes?.[EPSS_SCORE]?.value ?? DEFAULT_EPSS_VALUE;
    },
    enrichmentDataAction() {
      return getEnrichmentDataAction(this.scanner);
    },
    /**
     * Returns fix_available/false_positive attributes for display and mutation.
     *
     * When no explicit fix_available/false_positive attributes exist on the scanner,
     * hydrates from SCANNER_DEFAULT_ATTRIBUTES so that removeAttributesFilter and
     * selectFilter operate on real data — not synthetic defaults that would silently
     * inject new attributes into the policy YAML.
     */
    vulnerabilityAttributes() {
      const { vulnerability_attributes: attributes = {} } = this.scanner;
      const {
        [KNOWN_EXPLOITED]: kevFilter,
        [EPSS_SCORE]: epssFilter,
        [ENRICHMENT_DATA_UNAVAILABLE]: enrichmentData,
        ...rest
      } = attributes;

      if (Object.keys(rest).length === 0) {
        // Look up defaults by the scanner type constant (not this.scanner.type which
        // is the rule type e.g. 'scan_finding'). Shallow spread is safe here because
        // remaining attributes after filtering KEV/EPSS/enrichment are all boolean primitives.
        const defaults =
          SCANNER_DEFAULT_ATTRIBUTES[REPORT_TYPE_CONTAINER_SCANNING]?.vulnerability_attributes ||
          {};
        const {
          [KNOWN_EXPLOITED]: _kev,
          [EPSS_SCORE]: _epss,
          [ENRICHMENT_DATA_UNAVAILABLE]: _enrichment,
          ...defaultRest
        } = defaults;
        return { ...defaultRest };
      }

      return rest;
    },
    isAttributeFilterSelected() {
      return Object.keys(this.vulnerabilityAttributes).some((key) =>
        [FIX_AVAILABLE, FALSE_POSITIVE].includes(key),
      );
    },
    isExploitSettingsVisible() {
      const attributes = this.scanner?.vulnerability_attributes || {};
      return attributes[KNOWN_EXPLOITED] !== undefined || attributes[EPSS_SCORE] !== undefined;
    },
    filters() {
      const vulnerabilityAttributes = this.vulnerabilityAttributes || {};
      return {
        [FIX_AVAILABLE]: vulnerabilityAttributes[FIX_AVAILABLE] !== undefined,
        [FALSE_POSITIVE]: vulnerabilityAttributes[FALSE_POSITIVE] !== undefined,
        [ATTRIBUTE]: Boolean(
          vulnerabilityAttributes[FIX_AVAILABLE] !== undefined &&
          vulnerabilityAttributes[FALSE_POSITIVE] !== undefined,
        ),
        [EXPLOIT_SETTINGS]: this.isExploitSettingsVisible,
      };
    },
    isAttributeSelectorDisabled() {
      return Object.keys(this.vulnerabilityAttributes).length >= VULNERABILITY_ATTRIBUTES.length;
    },
  },
  methods: {
    triggerChanged(value) {
      this.$emit('changed', { ...this.scanner, ...value });
    },
    toggleCollapse() {
      this.localVisible = !this.localVisible;
    },
    setVulnerabilitiesAllowed(value) {
      this.triggerChanged({ vulnerabilities_allowed: value });
    },
    setIsMalicious(value) {
      this.triggerChanged({ is_malicious: value });
    },
    setKevFilter(value) {
      this.$emit('changed', {
        ...buildVulnerabilitiesPayload(this.scanner, KNOWN_EXPLOITED, value),
      });
    },
    setEpssFilter(value) {
      this.$emit('changed', {
        ...buildVulnerabilitiesPayload(this.scanner, EPSS_SCORE, value),
      });
    },
    setEnrichmentDataAction(action) {
      // Read raw YAML, not the hydrated `vulnerabilityAttributes` computed,
      // so absent KEV/EPSS keys stay absent through unrelated edits.
      const rawAttributes = this.scanner.vulnerability_attributes || {};
      const result = buildVulnerabilityAttributes({
        attributes: this.vulnerabilityAttributes,
        kevFilterValue: rawAttributes[KNOWN_EXPLOITED],
        epssOperator: rawAttributes[EPSS_SCORE]?.operator,
        epssValue: rawAttributes[EPSS_SCORE]?.value,
        enrichmentDataAction: action,
      });

      this.triggerChanged({ vulnerability_attributes: result });
    },
    setVulnerabilityAttributes(value) {
      // Read raw YAML, not the hydrated `vulnerabilityAttributes` computed,
      // so absent KEV/EPSS keys stay absent through unrelated edits.
      const rawAttributes = this.scanner.vulnerability_attributes || {};
      const result = buildVulnerabilityAttributes({
        attributes: value,
        kevFilterValue: rawAttributes[KNOWN_EXPLOITED],
        epssOperator: rawAttributes[EPSS_SCORE]?.operator,
        epssValue: rawAttributes[EPSS_SCORE]?.value,
        enrichmentDataAction: this.enrichmentDataAction,
      });

      if (result === null) {
        const { vulnerability_attributes, ...rest } = this.scanner;
        this.$emit('changed', rest);
      } else {
        this.triggerChanged({ vulnerability_attributes: result });
      }
    },
    removeAttributesFilter(attribute) {
      const { [attribute]: deletedAttribute, ...otherAttributes } = this.vulnerabilityAttributes;
      this.setVulnerabilityAttributes(otherAttributes);
    },
    removeExploitSettings() {
      this.$emit('changed', removeExploitSettingsFromScanner(this.scanner));
    },
    addExploitSettings() {
      this.triggerChanged({
        vulnerability_attributes: buildExploitSettingsAttributes(this.scanner),
      });
    },
    selectFilter(filter) {
      if (filter === EXPLOIT_SETTINGS) {
        this.addExploitSettings();
        return;
      }

      const attributeKey =
        Object.keys(this.vulnerabilityAttributes)[0] === FIX_AVAILABLE
          ? FALSE_POSITIVE
          : FIX_AVAILABLE;
      this.setVulnerabilityAttributes({
        ...this.vulnerabilityAttributes,
        [attributeKey]: true,
      });
    },
    shouldDisableFilter(filter) {
      if (filter === ATTRIBUTE) {
        return this.isAttributeSelectorDisabled;
      }
      return false;
    },
  },
};
</script>

<template>
  <div>
    <scanner-header
      :title="$options.i18n.title"
      :visible="localVisible"
      show-remove-button
      @toggle="toggleCollapse"
      @remove="$emit('remove')"
    />

    <gl-collapse v-model="localVisible">
      <vulnerabilities-allowed-section
        :vulnerabilities-allowed="vulnerabilitiesAllowed"
        @input="setVulnerabilitiesAllowed"
      />

      <malware-settings v-if="showMalwareSettings" :value="isMalicious" @input="setIsMalicious" />

      <exploit-settings-section
        v-if="isExploitSettingsVisible"
        :kev-filter-value="kevFilterValue"
        :epss-operator="epssOperator"
        :epss-value="epssValue"
        @kev-change="setKevFilter"
        @epss-change="setEpssFilter"
        @remove="removeExploitSettings"
      />

      <enrichment-data-settings
        :selected-action="enrichmentDataAction"
        @change="setEnrichmentDataAction"
      />

      <section-layout
        v-if="isAttributeFilterSelected"
        class="gl-mt-4 gl-bg-default gl-px-0 gl-py-0"
        content-classes="!gl-gap-0"
        :show-remove-button="false"
      >
        <template #content>
          <attribute-filters
            :selected="vulnerabilityAttributes"
            @remove="removeAttributesFilter"
            @input="setVulnerabilityAttributes"
          />
        </template>
      </section-layout>

      <section-layout
        class="gl-mt-4 gl-bg-default gl-px-0 gl-py-0"
        content-classes="!gl-gap-0"
        :show-remove-button="false"
      >
        <template #content>
          <div class="gl-w-full">
            <scan-filter-selector
              class="gl-w-full !gl-bg-default"
              :filters="$options.ATTRIBUTE_FILTERS"
              :selected="filters"
              :should-disable-filter="shouldDisableFilter"
              @select="selectFilter"
            />
          </div>
        </template>
      </section-layout>
    </gl-collapse>
  </div>
</template>
