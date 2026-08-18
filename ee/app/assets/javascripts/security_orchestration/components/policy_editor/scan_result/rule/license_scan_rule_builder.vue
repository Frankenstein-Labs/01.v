<script>
import { GlSprintf, GlAlert } from '@gitlab/ui';
import { s__ } from '~/locale';
import {
  buildFiltersFromLicenseRule,
  getDefaultRule,
  LICENSE_STATES,
} from 'ee/security_orchestration/components/policy_editor/scan_result/lib';
import {
  mapComponentLicenseFormatToYaml,
  parseAllowDenyLicenseList,
} from 'ee/security_orchestration/components/policy_editor/utils';
import BranchExceptionSelector from '../../branch_exception_selector.vue';
import ScanFilterSelector from '../../scan_filter_selector.vue';
import { SCAN_RESULT_BRANCH_TYPE_OPTIONS, BRANCH_EXCEPTIONS_KEY } from '../../constants';
import RuleMultiSelect from '../../rule_multi_select.vue';
import SectionLayout from '../../section_layout.vue';
import BranchSelection from '../../branch_selection.vue';
import StatusFilter from './scan_filters/status_filter.vue';
import LicenseFilter from './scan_filters/license_filter.vue';
import DenyAllowList from './deny_allow_list.vue';
import LicenseOverridesList from './license_overrides_list.vue';
import {
  STATUS,
  LICENCE_FILTERS,
  LICENSE_OVERRIDES,
  DENIED,
  ALLOW_DENY,
  ALLOWED,
  TYPE,
  OVERRIDES,
} from './scan_filters/constants';
import ScanTypeSelect from './scan_type_select.vue';

export default {
  name: 'LicenseScanRuleBuilder',
  STATUS,
  ALLOW_DENY,
  TYPE,
  OVERRIDES,
  components: {
    GlAlert,
    BranchExceptionSelector,
    DenyAllowList,
    LicenseOverridesList,
    SectionLayout,
    GlSprintf,
    LicenseFilter,
    BranchSelection,
    RuleMultiSelect,
    ScanFilterSelector,
    ScanTypeSelect,
    StatusFilter,
  },
  inject: ['namespaceType', 'enabledExperiments'],
  props: {
    initRule: {
      type: Object,
      required: true,
    },
  },
  emits: ['changed', 'error', 'set-scan-type'],
  i18n: {
    licenseStatuses: s__('ScanResultPolicy|license status'),
    licenseScanResultRuleCopy: s__(
      'ScanResultPolicy|When %{scanType} runs in an open merge request that targets %{branches} %{branchExceptions} and finds licenses match all of the following criteria:',
    ),
    validationErrorMessage: s__(
      'ScanResultPolicy|You can specify either a license state (allowlist or denylist) or a license type, not both.',
    ),
  },
  licenseStatuses: LICENSE_STATES,
  data() {
    const { licenses, isDenied } = parseAllowDenyLicenseList(this.initRule);

    return {
      selectedFilters: buildFiltersFromLicenseRule(this.initRule),
      excludeListType: isDenied ? DENIED : ALLOWED,
      licenses,
    };
  },
  computed: {
    licenseOverridesEnabled() {
      return this.enabledExperiments.includes('license_overrides');
    },
    availableFilters() {
      return LICENCE_FILTERS.filter(
        ({ value }) => value !== OVERRIDES || this.licenseOverridesEnabled,
      );
    },
    hasValidationError() {
      return 'license_types' in this.initRule && 'licenses' in this.initRule;
    },
    showDenyAllowListFilter() {
      return this.isFilterSelected(this.$options.ALLOW_DENY);
    },
    showOverridesFilter() {
      return this.licenseOverridesEnabled && this.isFilterSelected(this.$options.OVERRIDES);
    },
    currentOverrides() {
      return this.initRule[LICENSE_OVERRIDES] || [];
    },
    showLicensesTypesFilter() {
      return this.isFilterSelected(this.$options.TYPE);
    },
    branchExceptions() {
      return this.initRule.branch_exceptions;
    },
    branchTypes() {
      return SCAN_RESULT_BRANCH_TYPE_OPTIONS(this.namespaceType);
    },
    licenseStatuses: {
      get() {
        return this.initRule.license_states;
      },
      set(values) {
        this.triggerChanged({ license_states: values });
      },
    },
  },
  methods: {
    triggerChanged(value) {
      this.$emit('changed', { ...this.initRule, ...value });
    },
    setScanType(value) {
      const rule = getDefaultRule(value);
      this.$emit('set-scan-type', rule);
    },
    setBranchType(value) {
      this.$emit('changed', value);
    },
    removeExceptions() {
      const rule = { ...this.initRule };
      if (BRANCH_EXCEPTIONS_KEY in rule) {
        delete rule[BRANCH_EXCEPTIONS_KEY];
      }

      this.$emit('changed', rule);
    },
    selectExcludeListType(type) {
      this.excludeListType = type;
      this.licenses = [];
      this.triggerChanged({ licenses: { [type]: [] } });
    },
    selectLicenses(licenses) {
      this.licenses = licenses;
      this.triggerChanged({
        licenses: { [this.excludeListType]: mapComponentLicenseFormatToYaml(licenses) },
      });
    },
    isFilterSelected(filter) {
      return Boolean(this.selectedFilters[filter]);
    },
    shouldDisableFilterSelector(filter) {
      if (filter === TYPE) {
        return this.isFilterSelected(filter) || this.isFilterSelected(ALLOW_DENY);
      }

      if (filter === ALLOW_DENY) {
        return this.isFilterSelected(filter) || this.isFilterSelected(TYPE);
      }

      return this.isFilterSelected(filter);
    },
    selectFilter(filter, value = true) {
      this.selectedFilters = {
        ...this.selectedFilters,
        [filter]: value,
      };

      const rule = { ...this.initRule };

      if (filter === this.$options.ALLOW_DENY) {
        if (value) {
          rule.licenses = { [ALLOWED]: [] };
        } else {
          delete rule.licenses;
        }
      }

      if (filter === this.$options.TYPE) {
        if (value) {
          rule.license_types = [];
        } else {
          delete rule.license_types;
        }
      }

      if (filter === this.$options.OVERRIDES) {
        if (value) {
          rule[LICENSE_OVERRIDES] = [];
        } else {
          delete rule[LICENSE_OVERRIDES];
        }
      }

      this.$emit('changed', rule);
    },
    updateOverrides(overrides) {
      if (overrides.length === 0) {
        this.removeOverrides();
      } else {
        this.triggerChanged({ [LICENSE_OVERRIDES]: overrides });
      }
    },
    removeOverrides() {
      this.selectFilter(this.$options.OVERRIDES, false);
    },
    removeLicenseType() {
      this.selectFilter(this.$options.TYPE, false);
      const rule = { ...this.initRule };
      delete rule.license_types;

      this.$emit('changed', rule);
    },
  },
};
</script>

<template>
  <div>
    <section-layout class="gl-pb-0 gl-pr-0" :show-remove-button="false">
      <template #content>
        <section-layout class="!gl-bg-default" :show-remove-button="false">
          <template #content>
            <gl-sprintf :message="$options.i18n.licenseScanResultRuleCopy">
              <template #scanType>
                <scan-type-select :scan-type="initRule.type" @select="setScanType" />
              </template>

              <template #branches>
                <branch-selection
                  :init-rule="initRule"
                  :branch-types="branchTypes"
                  @changed="triggerChanged"
                  @set-branch-type="setBranchType"
                />
              </template>

              <template #branchExceptions>
                <branch-exception-selector
                  :selected-exceptions="branchExceptions"
                  @remove="removeExceptions"
                  @select="triggerChanged"
                />
              </template>
            </gl-sprintf>
          </template>
        </section-layout>
      </template>
    </section-layout>

    <section-layout class="gl-pr-0 gl-pt-3" :show-remove-button="false">
      <template #content>
        <status-filter
          :show-remove-button="false"
          class="!gl-bg-default @md/panel:gl-items-center"
          label-classes="!gl-text-base !gl-w-12 !gl-pl-0 !gl-font-bold"
        >
          <rule-multi-select
            v-model="licenseStatuses"
            class="!gl-inline gl-align-middle"
            :item-type-name="$options.i18n.licenseStatuses"
            :items="$options.licenseStatuses"
            @error="$emit('error', $event)"
          />
        </status-filter>

        <gl-alert v-if="hasValidationError" class="gl-w-full" :dismissible="false" variant="danger">
          {{ $options.i18n.validationErrorMessage }}
        </gl-alert>

        <license-filter
          v-if="showLicensesTypesFilter"
          class="!gl-bg-default"
          :has-error="hasValidationError"
          :init-rule="initRule"
          @changed="triggerChanged"
          @remove="removeLicenseType"
        />

        <deny-allow-list
          v-if="showDenyAllowListFilter"
          :has-error="hasValidationError"
          :selected="excludeListType"
          :licenses="licenses"
          @remove="selectFilter($options.ALLOW_DENY, false)"
          @select-type="selectExcludeListType"
          @select-licenses="selectLicenses"
        />

        <license-overrides-list
          v-if="showOverridesFilter"
          :overrides="currentOverrides"
          @update="updateOverrides"
          @remove="removeOverrides"
        />

        <scan-filter-selector
          :filters="availableFilters"
          :should-disable-filter="shouldDisableFilterSelector"
          class="gl-w-full gl-bg-default"
          @select="selectFilter"
        />
      </template>
    </section-layout>
  </div>
</template>
