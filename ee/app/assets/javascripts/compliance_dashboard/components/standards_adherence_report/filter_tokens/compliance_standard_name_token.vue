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
    standards() {
      return [
        {
          text: __('GitLab'),
          value: 'GITLAB',
        },
      ];
    },
  },
  methods: {
    findActiveStandard(inputValue) {
      const activeStandard = this.standards.find((standard) => standard.value === this.value.data);

      return activeStandard?.text || inputValue;
    },
  },
};
</script>

<template>
  <gl-filtered-search-token :config="config" v-bind="{ ...$props, ...$attrs }" v-on="glListeners()">
    <template #view="{ inputValue }">
      {{ findActiveStandard(inputValue) }}
    </template>
    <template #suggestions>
      <gl-filtered-search-suggestion
        v-for="(standard, index) in standards"
        :key="index"
        :value="standard.value"
      >
        {{ standard.text }}
      </gl-filtered-search-suggestion>
    </template>
  </gl-filtered-search-token>
</template>
