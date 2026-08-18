<script>
import { GlFilteredSearchToken, GlFilteredSearchSuggestion } from '@gitlab/ui';
import { __ } from '~/locale';
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
          text: __('All'),
          value: 'all',
        },
        {
          text: __('Archived'),
          value: 'archived',
        },
        {
          text: __('Non-archived'),
          value: 'non-archived',
        },
      ];
    },
    findActiveCheck() {
      return this.checks.find((check) => check.value === this.value.data);
    },
    tokenConfig() {
      return { ...this.config, operators: [{ value: '=', description: 'is', default: true }] };
    },
  },
};
</script>

<template>
  <gl-filtered-search-token
    :config="tokenConfig"
    v-bind="{ ...$props, ...$attrs }"
    v-on="glListeners()"
  >
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
