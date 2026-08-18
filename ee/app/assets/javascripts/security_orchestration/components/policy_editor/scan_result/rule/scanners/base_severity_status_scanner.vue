<script>
import { GlCollapse } from '@gitlab/ui';
import SectionLayout from 'ee/security_orchestration/components/policy_editor/section_layout.vue';
import ScanFilterSelector from 'ee/security_orchestration/components/policy_editor/scan_filter_selector.vue';
import VulnerabilitiesAllowedSection from 'ee/security_orchestration/components/policy_editor/scan_result/rule/scanners/vulnerabilities_allowed_section.vue';
import SeverityFilter from 'ee/security_orchestration/components/policy_editor/scan_result/rule/scan_filters/severity_filter.vue';
import StatusFilters from 'ee/security_orchestration/components/policy_editor/scan_result/rule/scan_filters/status_filters.vue';
import {
  STATUS,
  NEWLY_DETECTED,
  PREVIOUSLY_EXISTING,
} from 'ee/security_orchestration/components/policy_editor/scan_result/rule/scan_filters/constants';
import {
  buildFiltersFromRule,
  groupVulnerabilityStatesWithDefaults,
} from 'ee/security_orchestration/components/policy_editor/scan_result/lib';
import {
  normalizeVulnerabilityStates,
  selectFilter,
  updateSeverityLevels,
} from 'ee/security_orchestration/components/policy_editor/scan_result/rule/scanners/utils';
import ScannerHeader from 'ee/security_orchestration/components/policy_editor/scan_result/rule/scanners/scanner_header.vue';
import { STATUS_FILTER_OPTIONS } from 'ee/security_orchestration/components/policy_editor/scan_result/rule/scanners/constants';

export default {
  NEWLY_DETECTED,
  PREVIOUSLY_EXISTING,
  FILTER_OPTIONS: STATUS_FILTER_OPTIONS,
  name: 'BaseSeverityStatusScanner',
  components: {
    GlCollapse,
    SectionLayout,
    SeverityFilter,
    StatusFilters,
    ScanFilterSelector,
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
    title: {
      type: String,
      required: true,
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
      return this.scanner.severity_levels || [];
    },
    vulnerabilityStates() {
      const vulnerabilityStateGroups = groupVulnerabilityStatesWithDefaults(
        this.scanner.vulnerability_states,
      );
      return {
        [PREVIOUSLY_EXISTING]: vulnerabilityStateGroups[PREVIOUSLY_EXISTING],
        [NEWLY_DETECTED]: vulnerabilityStateGroups[NEWLY_DETECTED],
      };
    },
    isStatusFilterSelected() {
      return this.isFilterSelected(NEWLY_DETECTED) || this.isFilterSelected(PREVIOUSLY_EXISTING);
    },
    isStatusSelectorDisabled() {
      return Boolean(
        this.vulnerabilityStates[NEWLY_DETECTED] && this.vulnerabilityStates[PREVIOUSLY_EXISTING],
      );
    },
  },
  watch: {
    scanner(newScanner) {
      this.filters = buildFiltersFromRule(newScanner);
    },
  },
  methods: {
    isFilterSelected(filter) {
      return Boolean(this.filters[filter]);
    },
    triggerChanged(value) {
      this.$emit('changed', { ...this.scanner, ...value });
    },
    toggleCollapse() {
      this.localVisible = !this.localVisible;
    },
    setSeverityLevels(value) {
      this.$emit('changed', updateSeverityLevels(this.scanner, value));
    },
    setVulnerabilityStates(vulnerabilityStates) {
      this.triggerChanged({
        vulnerability_states: normalizeVulnerabilityStates(vulnerabilityStates),
      });
    },
    changeStatusGroup(value) {
      this.setVulnerabilityStates(value);
    },
    removeStatusFilter(filter) {
      this.setVulnerabilityStates({
        ...this.vulnerabilityStates,
        [filter]: null,
      });
    },
    setVulnerabilitiesAllowed(value) {
      this.triggerChanged({ vulnerabilities_allowed: value });
    },
    selectFilter(filter) {
      this.filters = selectFilter(filter, this.filters);
    },
    shouldDisableFilter(filter) {
      if (filter === STATUS) {
        return this.isStatusSelectorDisabled;
      }
      return false;
    },
  },
};
</script>

<template>
  <div>
    <scanner-header
      :title="title"
      :visible="localVisible"
      show-remove-button
      :is-default-configuration="isDefaultConfiguration"
      :show-default-rule-badge="showDefaultRuleBadge"
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
        v-if="isStatusFilterSelected"
        class="gl-mt-4 gl-bg-default gl-px-0 gl-py-0"
        content-classes="!gl-gap-0"
        :show-remove-button="false"
      >
        <template #content>
          <status-filters
            :filters="filters"
            :selected="vulnerabilityStates"
            @change-status-group="changeStatusGroup"
            @input="setVulnerabilityStates"
            @remove="removeStatusFilter"
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
              :filters="$options.FILTER_OPTIONS"
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
