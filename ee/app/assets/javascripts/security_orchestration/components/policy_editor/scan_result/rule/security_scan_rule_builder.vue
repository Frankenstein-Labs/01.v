<script>
import { isObject, pick } from 'lodash-es';
import { GlSprintf } from '@gitlab/ui';
import { s__, sprintf, n__ } from '~/locale';
import { REPORT_TYPES_DEFAULT } from 'ee/security_dashboard/constants';
import {
  REPORT_TYPE_API_FUZZING,
  REPORT_TYPE_CONTAINER_SCANNING,
  REPORT_TYPE_COVERAGE_FUZZING,
  REPORT_TYPE_DAST,
  REPORT_TYPE_DEPENDENCY_SCANNING,
  REPORT_TYPE_SAST,
  REPORT_TYPE_SECRET_DETECTION,
} from '~/vue_shared/security_reports/constants';
import {
  ANY_OPERATOR,
  GREATER_THAN_OPERATOR,
  BRANCH_EXCEPTIONS_KEY,
  SCAN_RESULT_BRANCH_TYPE_OPTIONS,
  VULNERABILITIES_ALLOWED_OPERATORS,
} from 'ee/security_orchestration/components/policy_editor/constants';
import BranchSelection from 'ee/security_orchestration/components/policy_editor/branch_selection.vue';
import BranchExceptionSelector from 'ee/security_orchestration/components/policy_editor/branch_exception_selector.vue';
import SectionLayout from 'ee/security_orchestration/components/policy_editor/section_layout.vue';
import RuleMultiSelect from 'ee/security_orchestration/components/policy_editor/rule_multi_select.vue';
import { enforceIntValue } from 'ee/security_orchestration/components/policy_editor/utils';
import {
  getDefaultRule,
  isDefaultScannerConfiguration,
  isRecommendedScannersSelection,
  resolveScannersFromSelection,
  buildDefaultScannerObject,
  RECOMMENDED_SCANNERS_KEY,
  DEFAULT_SCANNER_TYPES,
  SCANNER_VALID_KEYS,
} from '../lib';
import ScanTypeSelect from './scan_type_select.vue';
import NumberRangeSelect from './number_range_select.vue';
import DependencyScanner from './scanners/dependency_scanner.vue';
import SastScanner from './scanners/sast_scanner.vue';
import SecretDetectionScanner from './scanners/secret_detection_scanner.vue';
import ContainerScanningScanner from './scanners/container_scanning_scanner.vue';
import DastScanner from './scanners/dast_scanner.vue';
import ApiFuzzingScanner from './scanners/api_fuzzing_scanner.vue';
import CoverageFuzzingScanner from './scanners/coverage_fuzzing_scanner.vue';
import GlobalSettings from './scanners/global_settings.vue';

export default {
  REPORT_TYPE_API_FUZZING,
  REPORT_TYPE_CONTAINER_SCANNING,
  REPORT_TYPE_COVERAGE_FUZZING,
  REPORT_TYPE_DAST,
  REPORT_TYPE_DEPENDENCY_SCANNING,
  REPORT_TYPE_SAST,
  REPORT_TYPE_SECRET_DETECTION,
  VULNERABILITIES_ALLOWED_OPERATORS,
  i18n: {
    scanners: s__('SecurityOrchestration|scanners'),
    scanResultRuleCopy: s__(
      'SecurityOrchestration|When a %{scanType} with %{scanners} runs against %{branches} %{branchExceptions} and finds %{vulnerabilitiesNumber} vulnerability type that matches all the following criteria:',
    ),
    vulnerabilitiesAllowed: s__('SecurityOrchestration|vulnerabilities allowed'),
    recommendedLabel: s__('SecurityOrchestration|Recommended'),
  },
  name: 'SecurityScanRuleBuilder',
  components: {
    NumberRangeSelect,
    BranchExceptionSelector,
    BranchSelection,
    DependencyScanner,
    SastScanner,
    SecretDetectionScanner,
    ContainerScanningScanner,
    DastScanner,
    ApiFuzzingScanner,
    CoverageFuzzingScanner,
    GlobalSettings,
    GlSprintf,
    RuleMultiSelect,
    ScanTypeSelect,
    SectionLayout,
  },
  inject: ['namespaceType'],
  props: {
    initRule: {
      type: Object,
      required: true,
    },
  },
  emits: ['set-scan-type', 'changed', 'error'],
  computed: {
    branchExceptions() {
      return this.initRule.branch_exceptions;
    },
    branchTypes() {
      return SCAN_RESULT_BRANCH_TYPE_OPTIONS(this.namespaceType);
    },
    scanners() {
      return this.initRule.scanners || [];
    },
    scannerKeys() {
      const keys = this.scanners.map((scanner) => {
        if (isObject(scanner)) {
          return scanner.type;
        }

        return scanner;
      });

      if (isRecommendedScannersSelection(this.scanners)) {
        return [RECOMMENDED_SCANNERS_KEY, ...keys];
      }

      return keys;
    },
    scannersDropdownItems() {
      return {
        [RECOMMENDED_SCANNERS_KEY]: this.$options.i18n.recommendedLabel,
        ...REPORT_TYPES_DEFAULT,
      };
    },
    scannersToggleText() {
      if (!isRecommendedScannersSelection(this.scanners)) return '';

      return sprintf(
        n__(
          'SecurityOrchestration|Recommended (%{count} scanner)',
          'SecurityOrchestration|Recommended (%{count} scanners)',
          DEFAULT_SCANNER_TYPES.length,
        ),
        { count: DEFAULT_SCANNER_TYPES.length },
      );
    },
    scannerObjects() {
      return this.scanners.map((scanner) => {
        if (isObject(scanner)) {
          return scanner;
        }

        return {
          ...pick(this.initRule, SCANNER_VALID_KEYS),
          type: scanner,
        };
      });
    },
    selectedVulnerabilitiesOperator() {
      return this.vulnerabilitiesAllowed === 0 ? ANY_OPERATOR : GREATER_THAN_OPERATOR;
    },
    vulnerabilitiesAllowed() {
      return enforceIntValue(this.initRule.vulnerabilities_allowed);
    },
  },
  methods: {
    getScanner(scannerType) {
      return this.scannerObjects.find(({ type }) => type === scannerType);
    },
    handleVulnerabilitiesOperatorChange(value) {
      if (value === ANY_OPERATOR) {
        this.setVulnerabilitiesAllowed(0);
      }
    },
    setVulnerabilitiesAllowed(value) {
      this.triggerChanged({ vulnerabilities_allowed: value });
    },
    setScanType(value) {
      const rule = getDefaultRule(value);
      this.$emit('set-scan-type', rule);
    },
    setBranchType(value) {
      this.$emit('changed', value);
    },
    triggerChanged(value) {
      this.$emit('changed', { ...this.initRule, ...value });
    },
    updateGlobalSettings(rule) {
      this.$emit('changed', rule);
    },
    removeExceptions() {
      const rule = { ...this.initRule };
      if (BRANCH_EXCEPTIONS_KEY in rule) {
        delete rule[BRANCH_EXCEPTIONS_KEY];
      }

      this.$emit('changed', rule);
    },
    setScanners(values) {
      const scanners = resolveScannersFromSelection(values, this.scanners, this.scannerObjects);
      this.triggerChanged({ scanners });
    },
    setRange(value) {
      this.triggerChanged({ vulnerabilities_allowed: value });
    },
    setScanner(scanner) {
      const scanners = this.scannerObjects.map((s) =>
        s.type === scanner.type ? { ...scanner } : { ...s },
      );

      this.triggerChanged({
        scanners,
      });
    },
    removeScanner(scannerType) {
      const scanners = this.scannerObjects.filter(({ type }) => type !== scannerType);
      this.triggerChanged({ scanners });
    },
    isScannerDefault(scannerType) {
      const scanner = this.getScanner(scannerType);
      if (!scanner) return false;
      return isDefaultScannerConfiguration(scanner);
    },
    resetScanner(scannerType) {
      this.setScanner(buildDefaultScannerObject(scannerType));
    },
  },
};
</script>

<template>
  <section-layout
    class="gl-pr-0 gl-pt-0"
    :show-remove-button="false"
    @changed="$emit('changed', $event)"
  >
    <template #content>
      <section-layout :show-remove-button="false">
        <template #content>
          <gl-sprintf :message="$options.i18n.scanResultRuleCopy">
            <template #scanType>
              <scan-type-select :scan-type="initRule.type" @select="setScanType" />
            </template>

            <template #scanners>
              <rule-multi-select
                :value="scannerKeys"
                class="!gl-inline gl-align-middle"
                :item-type-name="$options.i18n.scanners"
                :items="scannersDropdownItems"
                :toggle-text-override="scannersToggleText"
                :show-reset-button="false"
                data-testid="scanners-select"
                @error="$emit('error', $event)"
                @input="setScanners"
              />
            </template>

            <template #branches>
              <branch-selection
                :init-rule="initRule"
                :branch-types="branchTypes"
                @changed="triggerChanged($event)"
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

            <template #vulnerabilitiesNumber>
              <number-range-select
                id="vulnerabilities-allowed"
                :value="vulnerabilitiesAllowed"
                :label="$options.i18n.vulnerabilitiesAllowed"
                :selected="selectedVulnerabilitiesOperator"
                :operators="$options.VULNERABILITIES_ALLOWED_OPERATORS"
                @operator-change="handleVulnerabilitiesOperatorChange"
                @input="setRange"
              />
            </template>
          </gl-sprintf>
        </template>
      </section-layout>

      <div class="gl-w-full gl-rounded-base gl-bg-default gl-p-4">
        <global-settings :scanner="initRule" @changed="updateGlobalSettings" />
      </div>

      <div
        v-if="getScanner($options.REPORT_TYPE_DEPENDENCY_SCANNING)"
        class="gl-w-full gl-rounded-base gl-p-4"
      >
        <dependency-scanner
          :scanner="getScanner($options.REPORT_TYPE_DEPENDENCY_SCANNING)"
          :visible="false"
          :is-default-configuration="isScannerDefault($options.REPORT_TYPE_DEPENDENCY_SCANNING)"
          show-default-rule-badge
          @changed="setScanner"
          @remove="removeScanner($options.REPORT_TYPE_DEPENDENCY_SCANNING)"
          @reset="resetScanner($options.REPORT_TYPE_DEPENDENCY_SCANNING)"
        />
      </div>

      <div v-if="getScanner($options.REPORT_TYPE_SAST)" class="gl-w-full gl-rounded-base gl-p-4">
        <sast-scanner
          :scanner="getScanner($options.REPORT_TYPE_SAST)"
          :visible="false"
          :is-default-configuration="isScannerDefault($options.REPORT_TYPE_SAST)"
          show-default-rule-badge
          @changed="setScanner"
          @remove="removeScanner($options.REPORT_TYPE_SAST)"
          @reset="resetScanner($options.REPORT_TYPE_SAST)"
        />
      </div>

      <div
        v-if="getScanner($options.REPORT_TYPE_SECRET_DETECTION)"
        class="gl-w-full gl-rounded-base gl-p-4"
      >
        <secret-detection-scanner
          :scanner="getScanner($options.REPORT_TYPE_SECRET_DETECTION)"
          :visible="false"
          :is-default-configuration="isScannerDefault($options.REPORT_TYPE_SECRET_DETECTION)"
          show-default-rule-badge
          @changed="setScanner"
          @remove="removeScanner($options.REPORT_TYPE_SECRET_DETECTION)"
          @reset="resetScanner($options.REPORT_TYPE_SECRET_DETECTION)"
        />
      </div>

      <div
        v-if="getScanner($options.REPORT_TYPE_CONTAINER_SCANNING)"
        class="gl-w-full gl-rounded-base gl-p-4"
      >
        <container-scanning-scanner
          :scanner="getScanner($options.REPORT_TYPE_CONTAINER_SCANNING)"
          :visible="false"
          @changed="setScanner"
          @remove="removeScanner($options.REPORT_TYPE_CONTAINER_SCANNING)"
        />
      </div>

      <div v-if="getScanner($options.REPORT_TYPE_DAST)" class="gl-w-full gl-rounded-base gl-p-4">
        <dast-scanner
          :scanner="getScanner($options.REPORT_TYPE_DAST)"
          :visible="false"
          @changed="setScanner"
          @remove="removeScanner($options.REPORT_TYPE_DAST)"
        />
      </div>

      <div
        v-if="getScanner($options.REPORT_TYPE_API_FUZZING)"
        class="gl-w-full gl-rounded-base gl-p-4"
      >
        <api-fuzzing-scanner
          :scanner="getScanner($options.REPORT_TYPE_API_FUZZING)"
          :visible="false"
          @changed="setScanner"
          @remove="removeScanner($options.REPORT_TYPE_API_FUZZING)"
        />
      </div>

      <div
        v-if="getScanner($options.REPORT_TYPE_COVERAGE_FUZZING)"
        class="gl-w-full gl-rounded-base gl-p-4"
      >
        <coverage-fuzzing-scanner
          :scanner="getScanner($options.REPORT_TYPE_COVERAGE_FUZZING)"
          :visible="false"
          @changed="setScanner"
          @remove="removeScanner($options.REPORT_TYPE_COVERAGE_FUZZING)"
        />
      </div>
    </template>
  </section-layout>
</template>
