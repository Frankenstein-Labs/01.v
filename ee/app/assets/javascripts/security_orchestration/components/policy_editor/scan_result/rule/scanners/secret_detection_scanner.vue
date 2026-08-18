<script>
import { GlCollapse } from '@gitlab/ui';
import { s__ } from '~/locale';
import { CRITICAL, HIGH } from 'ee/vulnerabilities/constants';
import SectionLayout from 'ee/security_orchestration/components/policy_editor/section_layout.vue';
import SeverityFilter from 'ee/security_orchestration/components/policy_editor/scan_result/rule/scan_filters/severity_filter.vue';
import VulnerabilitiesAllowedSection from 'ee/security_orchestration/components/policy_editor/scan_result/rule/scanners/vulnerabilities_allowed_section.vue';
import StatusFilter from 'ee/security_orchestration/components/policy_editor/scan_result/rule/scan_filters/status_filter.vue';
import { NEWLY_DETECTED } from 'ee/security_orchestration/components/policy_editor/scan_result/rule/scan_filters/constants';
import {
  buildFiltersFromRule,
  groupVulnerabilityStatesWithDefaults,
} from 'ee/security_orchestration/components/policy_editor/scan_result/lib';
import { updateSeverityLevels } from 'ee/security_orchestration/components/policy_editor/scan_result/rule/scanners/utils';
import ScannerHeader from 'ee/security_orchestration/components/policy_editor/scan_result/rule/scanners/scanner_header.vue';

export default {
  NEWLY_DETECTED,
  i18n: {
    title: s__('SecurityOrchestration|Secret Detection Scanning Rule'),
  },
  name: 'SecretDetectionScanner',
  components: {
    GlCollapse,
    SectionLayout,
    SeverityFilter,
    StatusFilter,
    ScannerHeader,
    VulnerabilitiesAllowedSection,
  },
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
    isDefaultConfiguration: {
      type: Boolean,
      required: false,
      default: false,
    },
    showDefaultRuleBadge: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  emits: ['changed', 'remove', 'reset'],
  data() {
    const filters = buildFiltersFromRule(this.scanner);

    return {
      localVisible: this.visible,
      filters,
    };
  },
  computed: {
    vulnerabilitiesAllowed() {
      return this.scanner.vulnerabilities_allowed || 0;
    },
    severityLevels() {
      return this.scanner.severity_levels?.length ? this.scanner.severity_levels : [CRITICAL, HIGH];
    },
    vulnerabilityStates() {
      const vulnerabilityStateGroups = groupVulnerabilityStatesWithDefaults(
        this.scanner.vulnerability_states,
      );
      return vulnerabilityStateGroups[NEWLY_DETECTED] || [];
    },
  },
  watch: {
    scanner(newScanner) {
      this.filters = buildFiltersFromRule(newScanner);
    },
  },
  methods: {
    triggerChanged(value) {
      this.$emit('changed', { ...this.scanner, ...value });
    },
    toggleCollapse() {
      this.localVisible = !this.localVisible;
    },
    setSeverityLevels(value) {
      this.$emit('changed', updateSeverityLevels(this.scanner, value));
    },
    setVulnerabilitiesAllowed(value) {
      this.triggerChanged({ vulnerabilities_allowed: value });
    },
    setVulnerabilityStates(vulnerabilityStates) {
      this.triggerChanged({
        vulnerability_states: vulnerabilityStates,
      });
    },
  },
};
</script>

<template>
  <div>
    <scanner-header
      :title="$options.i18n.title"
      :visible="localVisible"
      :is-default-configuration="isDefaultConfiguration"
      :show-default-rule-badge="showDefaultRuleBadge"
      show-remove-button
      @toggle="toggleCollapse"
      @remove="$emit('remove')"
      @reset="$emit('reset')"
    />

    <gl-collapse v-model="localVisible">
      <vulnerabilities-allowed-section
        :vulnerabilities-allowed="vulnerabilitiesAllowed"
        @input="setVulnerabilitiesAllowed"
      />

      <section-layout
        class="gl-mt-4 gl-bg-default gl-px-0 gl-py-0"
        content-classes="!gl-gap-0"
        :show-remove-button="false"
      >
        <template #content>
          <severity-filter
            class="!gl-bg-default"
            :selected="severityLevels"
            @input="setSeverityLevels"
          />
        </template>
      </section-layout>

      <section-layout
        class="gl-mt-4 gl-bg-default gl-px-0 gl-py-0"
        content-classes="!gl-gap-0"
        :show-remove-button="false"
      >
        <template #content>
          <status-filter
            :filter="$options.NEWLY_DETECTED"
            :selected="vulnerabilityStates"
            :disabled="true"
            label-classes="!gl-text-base !gl-w-12 !gl-pl-0 !gl-font-bold !gl-mt-2"
            :show-remove-button="false"
            @input="setVulnerabilityStates"
          />
        </template>
      </section-layout>
    </gl-collapse>
  </div>
</template>
