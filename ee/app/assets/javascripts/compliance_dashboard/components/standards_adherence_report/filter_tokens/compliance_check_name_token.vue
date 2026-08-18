<script>
import { GlFilteredSearchToken, GlFilteredSearchSuggestion } from '@gitlab/ui';
import { s__ } from '~/locale';
import { glListenersMixin } from '~/lib/utils/vue3compat/gl_listeners_mixin';

export default {
  components: {
    GlFilteredSearchToken,
    GlFilteredSearchSuggestion,
  },
  mixins: [glListenersMixin],
  props: {
    config: {
      type: Object,
      required: true,
    },
    value: {
      type: Object,
      required: true,
    },
  },
  computed: {
    checks() {
      return [
        {
          text: s__('ComplianceStandardsAdherence|At least two approvals'),
          value: 'AT_LEAST_TWO_APPROVALS',
        },
        {
          text: s__('ComplianceStandardsAdherence|Prevent authors as approvers'),
          value: 'PREVENT_APPROVAL_BY_MERGE_REQUEST_AUTHOR',
        },
        {
          text: s__('ComplianceStandardsAdherence|Prevent committers as approvers'),
          value: 'PREVENT_APPROVAL_BY_MERGE_REQUEST_COMMITTERS',
        },
      ];
    },
    findActiveCheck() {
      return this.checks.find((check) => check.value === this.value.data);
    },
  },
};
</script>

<template>
  <gl-filtered-search-token :config="config" v-bind="{ ...$props, ...$attrs }" v-on="glListeners()">
    <template #view>
      {{ findActiveCheck.text }}
    </template>
    <template #suggestions>
      <gl-filtered-search-suggestion
        v-for="(check, index) in checks"
        :key="index"
        :value="check.value"
      >
        {{ check.text }}
      </gl-filtered-search-suggestion>
    </template>
  </gl-filtered-search-token>
</template>
