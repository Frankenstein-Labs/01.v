<script>
import { GlSprintf } from '@gitlab/ui';
import { s__ } from '~/locale';
import BranchSelection from 'ee/security_orchestration/components/policy_editor/branch_selection.vue';
import BranchExceptionSelector from 'ee/security_orchestration/components/policy_editor/branch_exception_selector.vue';
import SectionLayout from 'ee/security_orchestration/components/policy_editor/section_layout.vue';
import { VULNERABILITIES_ALLOWED_OPERATORS } from 'ee/security_orchestration/components/policy_editor/constants';
import NumberRangeSelect from 'ee/security_orchestration/components/policy_editor/scan_result/rule/number_range_select.vue';

export default {
  VULNERABILITIES_ALLOWED_OPERATORS,
  i18n: {
    scanResultRuleCopy: s__(
      'SecurityOrchestration|Runs against %{branches} %{branchExceptions} and finds %{vulnerabilitiesNumber} vulnerability type that matches all the following criteria:',
    ),
    vulnerabilitiesAllowed: s__('SecurityOrchestration|vulnerabilities allowed'),
  },
  name: 'BranchRuleSection',
  components: {
    BranchSelection,
    BranchExceptionSelector,
    GlSprintf,
    NumberRangeSelect,
    SectionLayout,
  },
  props: {
    scanner: {
      type: Object,
      required: true,
    },
    branchTypes: {
      type: Array,
      required: true,
    },
    branchExceptions: {
      type: Array,
      required: false,
      default: () => [],
    },
    vulnerabilitiesAllowed: {
      type: Number,
      required: true,
    },
    selectedOperator: {
      type: String,
      required: true,
    },
  },
  emits: ['changed', 'set-branch-type', 'remove-exceptions', 'operator-change', 'range-input'],
};
</script>

<template>
  <section-layout class="gl-bg-default" :show-remove-button="false">
    <template #content>
      <gl-sprintf :message="$options.i18n.scanResultRuleCopy">
        <template #branches>
          <branch-selection
            :init-rule="scanner"
            :branch-types="branchTypes"
            @changed="$emit('changed', $event)"
            @set-branch-type="$emit('set-branch-type', $event)"
          />
        </template>

        <template #branchExceptions>
          <branch-exception-selector
            :selected-exceptions="branchExceptions"
            @remove="$emit('remove-exceptions')"
            @select="$emit('changed', $event)"
          />
        </template>

        <template #vulnerabilitiesNumber>
          <number-range-select
            id="vulnerabilities-allowed"
            :value="vulnerabilitiesAllowed"
            :label="$options.i18n.vulnerabilitiesAllowed"
            :selected="selectedOperator"
            :operators="$options.VULNERABILITIES_ALLOWED_OPERATORS"
            @operator-change="$emit('operator-change', $event)"
            @input="$emit('range-input', $event)"
          />
        </template>
      </gl-sprintf>
    </template>
  </section-layout>
</template>
