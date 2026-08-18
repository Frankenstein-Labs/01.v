<script>
import { GlFilteredSearchToken, GlFilteredSearchSuggestion } from '@gitlab/ui';
import { COMPLIANCE_STATUS_OPTIONS } from 'ee/vue_shared/compliance/constants';
import { glListenersMixin } from '~/lib/utils/vue3compat/gl_listeners_mixin';

export default {
  name: 'StatusToken',
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
    statusOptions() {
      return COMPLIANCE_STATUS_OPTIONS;
    },
  },
  methods: {
    findActiveStatusName(inputValue) {
      // Handle both lowercase and uppercase values for compatibility
      const normalizedValue = inputValue?.toLowerCase();
      return this.statusOptions.find((s) => s.value === normalizedValue)?.text || inputValue;
    },
  },
};
</script>

<template>
  <gl-filtered-search-token :config="config" v-bind="{ ...$props, ...$attrs }" v-on="glListeners()">
    <template #view="{ inputValue }">
      {{ findActiveStatusName(inputValue) }}
    </template>
    <template #suggestions>
      <gl-filtered-search-suggestion
        v-for="status in statusOptions"
        :key="status.value"
        :value="status.value"
      >
        {{ status.text }}
      </gl-filtered-search-suggestion>
    </template>
  </gl-filtered-search-token>
</template>
