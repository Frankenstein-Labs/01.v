<script>
import { GlFilteredSearchSuggestion } from '@gitlab/ui';
import { createAlert } from '~/alert';
import { __ } from '~/locale';
import BaseToken from '~/vue_shared/components/filtered_search_bar/tokens/base_token.vue';
import getNamespaceProjects from 'ee/graphql_shared/queries/get_namespace_projects.query.graphql';
import { glListenersMixin } from '~/lib/utils/vue3compat/gl_listeners_mixin';

export default {
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
      shouldFetch: false,
      searchTerm: '',
      projects: [],
    };
  },
  apollo: {
    projects: {
      query: getNamespaceProjects,
      skip() {
        return !this.shouldFetch;
      },
      variables() {
        return {
          fullPath: this.config.fullPath,
          search: this.searchTerm,
        };
      },
      update(data) {
        return data.group?.projects?.nodes || [];
      },
      error() {
        createAlert({ message: __('There was a problem fetching projects.') });
      },
    },
  },
  computed: {
    loading() {
      return this.$apollo.queries.projects?.loading ?? false;
    },
  },
  methods: {
    fetchProjects(search = '') {
      this.searchTerm = search;
      this.shouldFetch = true;
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
