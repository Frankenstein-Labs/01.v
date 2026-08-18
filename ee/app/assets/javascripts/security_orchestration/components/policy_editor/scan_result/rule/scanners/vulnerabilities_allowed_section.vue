<script>
import { GlSprintf } from '@gitlab/ui';
import { s__ } from '~/locale';
import SectionLayout from 'ee/security_orchestration/components/policy_editor/section_layout.vue';
import {
  ANY_OPERATOR,
  VULNERABILITIES_ALLOWED_OPERATORS,
} from 'ee/security_orchestration/components/policy_editor/constants';
import NumberRangeSelect from 'ee/security_orchestration/components/policy_editor/scan_result/rule/number_range_select.vue';
import { getSelectedVulnerabilitiesOperator } from 'ee/security_orchestration/components/policy_editor/scan_result/rule/scanners/utils';

export default {
  VULNERABILITIES_ALLOWED_OPERATORS,
  i18n: {
    vulnerabilitiesAllowed: s__('SecurityOrchestration|vulnerabilities allowed'),
    sentenceText: s__(
      'SecurityOrchestration|Finds %{vulnerabilitiesNumber} vulnerability type that matches all the following criteria:',
    ),
  },
  name: 'VulnerabilitiesAllowedSection',
  components: {
    GlSprintf,
    SectionLayout,
    NumberRangeSelect,
  },
  props: {
    vulnerabilitiesAllowed: {
      type: Number,
      required: false,
      default: 0,
    },
  },
  emits: ['input'],
  computed: {
    selectedOperator() {
      return getSelectedVulnerabilitiesOperator(this.vulnerabilitiesAllowed);
    },
  },
  methods: {
    handleOperatorChange(operator) {
      if (operator === ANY_OPERATOR) {
        this.$emit('input', 0);
      }
    },
  },
};
</script>

<template>
  <section-layout class="gl-bg-default" content-classes="!gl-gap-0" :show-remove-button="false">
    <template #content>
      <gl-sprintf :message="$options.i18n.sentenceText">
        <template #vulnerabilitiesNumber>
          <number-range-select
            id="scanner-vulnerabilities-allowed"
            class="gl-mx-3"
            :value="vulnerabilitiesAllowed"
            :label="$options.i18n.vulnerabilitiesAllowed"
            :selected="selectedOperator"
            :operators="$options.VULNERABILITIES_ALLOWED_OPERATORS"
            @operator-change="handleOperatorChange"
            @input="$emit('input', $event)"
          />
        </template>
      </gl-sprintf>
    </template>
  </section-layout>
</template>
