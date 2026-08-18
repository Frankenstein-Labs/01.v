<script>
import { s__ } from '~/locale';
import { glListenersMixin } from '~/lib/utils/vue3compat/gl_listeners_mixin';
import BaseSearchToken from './tracing_base_search_token.vue';

export default {
  name: 'AttributeSearchToken',
  components: {
    BaseSearchToken,
  },
  mixins: [glListenersMixin],
  i18n: {
    placeholderName: s__('Tracing|name'),
    placeholderValue: s__('Tracing|value'),
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
  },
};
</script>

<template>
  <base-search-token
    v-bind="$attrs"
    :active="active"
    :config="config"
    :value="value"
    :data-segment-input-attributes="inputAttributes"
    v-on="glListeners()"
  />
</template>
