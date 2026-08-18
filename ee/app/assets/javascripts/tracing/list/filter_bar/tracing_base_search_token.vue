<script>
import { GlDropdownText, GlFilteredSearchToken } from '@gitlab/ui';
import { s__ } from '~/locale';
import { glListenersMixin } from '~/lib/utils/vue3compat/gl_listeners_mixin';
import { SERVICE_NAME_FILTER_TOKEN_TYPE, OPERATION_FILTER_TOKEN_TYPE } from './filters';

export default {
  name: 'TracingBaseSearchToken',
  components: {
    GlFilteredSearchToken,
    GlDropdownText,
  },
  mixins: [glListenersMixin],
  i18n: {
    disabledText: s__('Tracing|You must select a Service and Operation first.'),
  },
  props: {
    active: {
      type: Boolean,
      required: true,
    },
    config: {
      type: Object,
      required: true,
    },
    value: {
      type: Object,
      required: true,
    },
    currentValue: {
      type: Array,
      required: true,
    },
  },
  computed: {
    isViewOnly() {
      const requiredFilters = [SERVICE_NAME_FILTER_TOKEN_TYPE, OPERATION_FILTER_TOKEN_TYPE];
      const hasAllRequiredFilters = requiredFilters.every((filter) =>
        this.currentValue.find(({ type }) => type === filter),
      );
      return !hasAllRequiredFilters;
    },
    computedConfig() {
      const operators = this.config.operators ?? [];
      return {
        ...this.config,
        // having multiple operators in view-only seem to break the token
        operators: this.isViewOnly ? [operators[0]] : operators,
      };
    },
  },
};
</script>

<template>
  <gl-filtered-search-token
    v-bind="{ ...$props, ...$attrs }"
    :config="computedConfig"
    :value="value"
    :active="active"
    :view-only="isViewOnly"
    v-on="glListeners()"
  >
    <template #suggestions>
      <gl-dropdown-text v-if="isViewOnly">{{ $options.i18n.disabledText }}</gl-dropdown-text>
    </template>
  </gl-filtered-search-token>
</template>
