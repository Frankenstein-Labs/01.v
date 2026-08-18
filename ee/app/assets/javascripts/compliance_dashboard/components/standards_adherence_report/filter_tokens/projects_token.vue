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
    findActiveProject(inputValue) {
      const activeProject = this.config.projects.find((project) => project.id === this.value.data);

      return activeProject?.name || inputValue;
    },
  },
};
</script>

<template>
  <gl-filtered-search-token :config="config" v-bind="{ ...$props, ...$attrs }" v-on="glListeners()">
    <template #view="{ inputValue }">
      {{ findActiveProject(inputValue) }}
    </template>
    <template #suggestions>
      <gl-filtered-search-suggestion
        v-for="(project, index) in config.projects"
        :key="index"
        :value="project.id"
      >
        {{ project.name }}
      </gl-filtered-search-suggestion>
    </template>
  </gl-filtered-search-token>
</template>
