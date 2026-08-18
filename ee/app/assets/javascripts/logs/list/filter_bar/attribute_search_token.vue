<script>
import BaseToken from '~/vue_shared/components/filtered_search_bar/tokens/base_token.vue';
import { s__ } from '~/locale';
import { glListenersMixin } from '~/lib/utils/vue3compat/gl_listeners_mixin';

export default {
  components: {
    BaseToken,
  },
  mixins: [glListenersMixin],
  i18n: {
    placeholderName: s__('ObservabilityLogs|name'),
    placeholderValue: s__('ObservabilityLogs|value'),
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
  },
  computed: {
    inputAttributes() {
      return {
        placeholder: `${this.$options.i18n.placeholderName}=${this.$options.i18n.placeholderValue}`,
      };
    },
    tokenConfig() {
      return {
        ...this.config,
        suggestionsDisabled: true,
      };
    },
  },
};
</script>

<template>
  <base-token
    v-bind="$attrs"
    :active="active"
    :config="tokenConfig"
    :value="value"
    :data-segment-input-attributes="inputAttributes"
    v-on="glListeners()"
  />
</template>
