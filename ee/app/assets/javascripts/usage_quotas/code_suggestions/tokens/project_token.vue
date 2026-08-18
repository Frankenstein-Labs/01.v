<script>
import { GlFilteredSearchSuggestion } from '@gitlab/ui';
import { createAlert } from '~/alert';
import { __ } from '~/locale';
import BaseToken from '~/vue_shared/components/filtered_search_bar/tokens/base_token.vue';
import getNamespaceProjects from 'ee/graphql_shared/queries/get_namespace_projects.query.graphql';
import { OPTIONS_NONE_ANY } from '~/vue_shared/components/filtered_search_bar/constants';
import { glListenersMixin } from '~/lib/utils/vue3compat/gl_listeners_mixin';

export default {
  name: 'ProjectToken',
  separator: '::',
  components: {
    BaseToken,
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
    active: {
      type: Boolean,
      required: true,
    },
  },
  data() {
    return {
      loading: false,
      projects: [],
    };
  },
  computed: {
    defaultProjects() {
      return OPTIONS_NONE_ANY;
    },
  },
  methods: {
    fetchProjects(search = '') {
      this.loading = true;
      return this.$apollo
        .query({
          query: getNamespaceProjects,
          variables: { fullPath: this.config.fullPath, search },
        })
        .then(({ data }) => {
          this.projects = data.group?.projects?.nodes || [];
        })
        .catch(() => {
          createAlert({ message: __('There was a problem fetching projects.') });
        })
        .finally(() => {
          this.loading = false;
        });
    },
    getActiveProject(projects, data) {
      if (!data) {
        return undefined;
      }
      return projects.find((project) => this.getValue(project) === data);
    },
    getValue(project) {
      return project.id;
    },
    displayValue(project) {
      return project?.name;
    },
  },
};
</script>

<template>
  <base-token
    v-bind="$attrs"
    :config="config"
    :value="value"
    :active="active"
    :default-suggestions="defaultProjects"
    :suggestions-loading="loading"
    :suggestions="projects"
    :get-active-token-value="getActiveProject"
    search-by="title"
    v-on="glListeners()"
    @fetch-suggestions="fetchProjects"
  >
    <template #view="{ viewTokenProps: { inputValue, activeTokenValue } }">
      {{ activeTokenValue ? displayValue(activeTokenValue) : inputValue }}
    </template>
    <template #suggestions-list="{ suggestions }">
      <gl-filtered-search-suggestion
        v-for="project in suggestions"
        :key="project.id"
        :value="getValue(project)"
      >
        {{ project.name }}
      </gl-filtered-search-suggestion>
    </template>
  </base-token>
</template>
