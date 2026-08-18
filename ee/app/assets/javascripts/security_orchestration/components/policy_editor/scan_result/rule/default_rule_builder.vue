<script>
import { GlSprintf } from '@gitlab/ui';
import { s__ } from '~/locale';
import BranchExceptionSelector from '../../branch_exception_selector.vue';
import ScanFilterSelector from '../../scan_filter_selector.vue';
import { BRANCH_EXCEPTIONS_KEY, SCAN_RESULT_BRANCH_TYPE_OPTIONS } from '../../constants';
import SectionLayout from '../../section_layout.vue';
import { getDefaultRule } from '../lib';
import BranchSelection from '../../branch_selection.vue';
import ScanTypeSelect from './scan_type_select.vue';

export default {
  emptyRuleCopy: s__(
    'ScanResultPolicy|When %{scanners} finds scanner-specific conditions in an open merge request that targets %{branches} %{branchExceptions} and matches %{boldDescription} the following criteria',
  ),
  i18n: {
    tooltipFilterDisabledTitle: s__('ScanResultPolicy|Select a scan type before adding criteria'),
  },
  name: 'DefaultRuleBuilder',
  components: {
    BranchExceptionSelector,
    SectionLayout,
    GlSprintf,
    BranchSelection,
    ScanTypeSelect,
    ScanFilterSelector,
  },
  inject: ['namespaceType'],
  props: {
    errorSources: {
      type: Array,
      required: false,
      default: () => [],
    },
    index: {
      type: Number,
      required: false,
      default: 0,
    },
  },
  emits: ['changed', 'error', 'set-scan-type'],
  data() {
    return {
      selectedBranches: [],
      selectedBranchType: null,
      selectedExceptions: [],
    };
  },
  computed: {
    ruleWithSelectedBranchesOnly() {
      return { branches: this.selectedBranches };
    },
    branchTypes() {
      return SCAN_RESULT_BRANCH_TYPE_OPTIONS(this.namespaceType);
    },
  },
  methods: {
    selectScanType(type) {
      const rule = getDefaultRule(type);

      if (this.selectedBranches.length > 0) {
        rule.branches = this.selectedBranches;
        delete rule.branch_type;
      }

      if (this.selectedBranchType) {
        rule.branch_type = this.selectedBranchType;
        delete rule.branches;
      }

      if (this.selectedExceptions.length > 0) {
        rule.branch_exceptions = this.selectedExceptions;
      }

      if (this.selectedExceptions.length === 0 && BRANCH_EXCEPTIONS_KEY in rule) {
        delete rule[BRANCH_EXCEPTIONS_KEY];
      }

      this.$emit('set-scan-type', rule);
    },
    setBranchType({ branch_type: branchType }) {
      this.selectedBranchType = branchType;
    },
    setSelectedBranches({ branches }) {
      this.selectedBranches = branches;
    },
    setSelectedExceptions({ branch_exceptions: branchExceptions }) {
      this.selectedExceptions = branchExceptions;
    },
    removeExceptions() {
      this.selectedExceptions = [];
    },
  },
};
</script>

<template>
  <div>
    <section-layout
      class="gl-pb-0 gl-pr-0"
      :show-remove-button="false"
      @changed="$emit('changed', $event)"
    >
      <template #content>
        <section-layout class="!gl-bg-default" :show-remove-button="false">
          <template #content>
            <gl-sprintf :message="$options.emptyRuleCopy">
              <template #scanners>
                <scan-type-select
                  :error-sources="errorSources"
                  :index="index"
                  @select="selectScanType"
                />
              </template>

              <template #branches>
                <branch-selection
                  :init-rule="ruleWithSelectedBranchesOnly"
                  :branch-types="branchTypes"
                  @changed="setSelectedBranches"
                  @set-branch-type="setBranchType"
                  @error="$emit('error', $event)"
                />
              </template>

              <template #branchExceptions>
                <branch-exception-selector
                  :selected-exceptions="selectedExceptions"
                  @remove="removeExceptions"
                  @select="setSelectedExceptions"
                />
              </template>

              <template #boldDescription>
                <b>{{ __('all') }}</b>
              </template>
            </gl-sprintf>
          </template>
        </section-layout>
      </template>
    </section-layout>
    <section-layout class="gl-pr-0 gl-pt-3" :show-remove-button="false">
      <template #content>
        <scan-filter-selector
          :disabled="true"
          :tooltip-title="$options.i18n.tooltipFilterDisabledTitle"
          class="gl-w-full !gl-bg-default"
        />
      </template>
    </section-layout>
  </div>
</template>
