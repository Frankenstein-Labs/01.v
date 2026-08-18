<script>
import { GlFilteredSearchToken, GlFilteredSearchSuggestion } from '@gitlab/ui';
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
  methods: {
    findActiveRequirementName(inputValue) {
      return this.config.requirements.find((f) => f.id === inputValue)?.name || inputValue;
    },
  },
};
</script>

<template>
  <gl-filtered-search-token :config="config" v-bind="{ ...$props, ...$attrs }" v-on="glListeners()">
    <template #view="{ inputValue }">
      {{ findActiveRequirementName(inputValue) }}
    </template>
    <template #suggestions>
      <gl-filtered-search-suggestion
        v-for="requirement in config.requirements"
        :key="requirement.id"
        :value="requirement.id"
      >
        {{ requirement.name }}
      </gl-filtered-search-suggestion>
    </template>
  </gl-filtered-search-token>
</template>
