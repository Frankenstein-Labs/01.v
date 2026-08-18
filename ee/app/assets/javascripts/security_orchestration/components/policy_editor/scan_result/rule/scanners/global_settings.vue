<script>
import { isEmpty } from 'lodash-es';
import { s__ } from '~/locale';
import AgeFilter from 'ee/security_orchestration/components/policy_editor/scan_result/rule/scan_filters/age_filter.vue';
import AttributeFilters from 'ee/security_orchestration/components/policy_editor/scan_result/rule/scan_filters/attribute_filters.vue';
import ScanFilterSelector from 'ee/security_orchestration/components/policy_editor/scan_filter_selector.vue';
import SectionLayout from 'ee/security_orchestration/components/policy_editor/section_layout.vue';
import SeverityFilter from 'ee/security_orchestration/components/policy_editor/scan_result/rule/scan_filters/severity_filter.vue';
import StatusFilters from 'ee/security_orchestration/components/policy_editor/scan_result/rule/scan_filters/status_filters.vue';
import { SEVERITY_LEVELS } from 'ee/security_dashboard/constants';
import {
  AGE,
  FILTERS,
  NEWLY_DETECTED,
  PREVIOUSLY_EXISTING,
  FIX_AVAILABLE,
  FALSE_POSITIVE,
} from 'ee/security_orchestration/components/policy_editor/scan_result/rule/scan_filters/constants';
import {
  buildFiltersFromRule,
  groupVulnerabilityStatesWithDefaults,
} from 'ee/security_orchestration/components/policy_editor/scan_result/lib';
import {
  normalizeVulnerabilityStates,
  getAgeTooltip,
  selectFilter,
  removePropertyFromPayload,
  selectEmptyArrayWhenAllSelected,
} from './utils';

export default {
  FILTERS,
  i18n: {
    title: s__('SecurityOrchestration|Global Settings'),
    description: s__(
      'SecurityOrchestration|Severity and status settings will apply to all scan rules',
    ),
  },
  name: 'GlobalSettings',
  components: {
    AgeFilter,
    AttributeFilters,
    ScanFilterSelector,
    SectionLayout,
    SeverityFilter,
    StatusFilters,
  },
  props: {
    scanner: {
      type: Object,
      required: true,
    },
  },
  emits: ['changed'],
  data() {
    return {
      filters: buildFiltersFromRule(this.scanner),
    };
  },
  computed: {
    isAgeFilterSelected() {
      return this.isFilterSelected(AGE);
    },
    isAttributeFilterSelected() {
      return this.isFilterSelected(FIX_AVAILABLE) || this.isFilterSelected(FALSE_POSITIVE);
    },
    isStatusFilterSelected() {
      return this.isFilterSelected(NEWLY_DETECTED) || this.isFilterSelected(PREVIOUSLY_EXISTING);
    },
    severityLevels() {
      const { severity_levels: severityLevels = [] } = this.scanner;

      if (!Array.isArray(severityLevels)) {
        return [];
      }

      return severityLevels.length === 0 ? Object.keys(SEVERITY_LEVELS) : severityLevels;
    },
    vulnerabilityAge() {
      return this.scanner.vulnerability_age;
    },
    vulnerabilityAttributes() {
      return this.scanner?.vulnerability_attributes || {};
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
  },
  watch: {
    scanner(newScanner) {
      this.filters = buildFiltersFromRule(newScanner);

      if (isEmpty(this.vulnerabilityStates[PREVIOUSLY_EXISTING]) && this.isAgeFilterSelected) {
        this.removeAgeFilter();
      }
    },
  },
  methods: {
    customFilterSelectorTooltip(filter) {
      return getAgeTooltip(filter, this.vulnerabilityStates);
    },
    isFilterSelected(filter) {
      return Boolean(this.filters[filter]);
    },
    changeStatusGroup(states) {
      this.setVulnerabilityStates(states);
    },
    removeStatusFilter(filter) {
      this.setVulnerabilityStates({
        ...this.vulnerabilityStates,
        [filter]: null,
      });
    },
    removeAgeFilter() {
      this.setVulnerabilityAge(null);
    },
    removeAttributesFilter(attribute) {
      this.setVulnerabilityAttributes(
        removePropertyFromPayload(this.vulnerabilityAttributes, attribute),
      );
    },
    removeFilterFromRule(filter) {
      this.$emit('changed', removePropertyFromPayload(this.scanner, filter));
    },
    setSeverityLevels(value) {
      this.triggerChanged({
        severity_levels: selectEmptyArrayWhenAllSelected(
          value,
          Object.keys(SEVERITY_LEVELS).length,
        ),
      });
    },
    shouldDisableFilterSelector(filter) {
      if (filter !== AGE) {
        return false;
      }

      return !this.vulnerabilityStates[PREVIOUSLY_EXISTING]?.length;
    },
    setVulnerabilityAge(value) {
      if (!value) {
        this.removeFilterFromRule('vulnerability_age');
      } else {
        this.triggerChanged({ vulnerability_age: value });
      }
    },
    setVulnerabilityAttributes(attributes) {
      if (isEmpty(attributes)) {
        this.removeFilterFromRule('vulnerability_attributes');
        return;
      }

      this.triggerChanged({
        vulnerability_attributes: attributes,
      });
    },
    setVulnerabilityStates(vulnerabilityStates) {
      this.triggerChanged({
        vulnerability_states: normalizeVulnerabilityStates(vulnerabilityStates),
      });
    },
    triggerChanged(value) {
      this.$emit('changed', { ...this.scanner, ...value });
    },
    selectFilter(filter) {
      this.filters = selectFilter(filter, this.filters, {
        onAttribute: this.setVulnerabilityAttributes,
        vulnerabilityAttributes: this.vulnerabilityAttributes,
      });
    },
  },
};
</script>

<template>
  <section-layout class="gl-w-full" :show-remove-button="false">
    <template #content>
      <div class="gl-w-full">
        <div>
          <h5 class="gl-mb-2">{{ $options.i18n.title }}</h5>
          <p class="gl-mb-0">{{ $options.i18n.description }}</p>
        </div>

        <div class="gl-mt-4">
          <severity-filter
            class="!gl-bg-default"
            :selected="severityLevels"
            @input="setSeverityLevels"
          />
        </div>

        <div v-if="isStatusFilterSelected" class="gl-mt-4">
          <status-filters
            :filters="filters"
            :selected="vulnerabilityStates"
            @remove="removeStatusFilter"
            @change-status-group="changeStatusGroup"
            @input="setVulnerabilityStates"
          />
        </div>

        <div v-if="isAgeFilterSelected" class="gl-mt-4">
          <age-filter
            :selected="vulnerabilityAge"
            @remove="removeAgeFilter"
            @input="setVulnerabilityAge"
          />
        </div>

        <div v-if="isAttributeFilterSelected" class="gl-mt-4">
          <attribute-filters
            :selected="vulnerabilityAttributes"
            @remove="removeAttributesFilter"
            @input="setVulnerabilityAttributes"
          />
        </div>
      </div>

      <div class="gl-mt-2 gl-w-full">
        <scan-filter-selector
          class="gl-w-full !gl-bg-default"
          :filters="$options.FILTERS"
          :selected="filters"
          :should-disable-filter="shouldDisableFilterSelector"
          :custom-filter-tooltip="customFilterSelectorTooltip"
          @select="selectFilter"
        />
      </div>
    </template>
  </section-layout>
</template>
