<script>
import { GlFilteredSearchSuggestion } from '@gitlab/ui';
import { createAlert } from '~/alert';
import { s__ } from '~/locale';
import BaseToken from '~/vue_shared/components/filtered_search_bar/tokens/base_token.vue';
import { glListenersMixin } from '~/lib/utils/vue3compat/gl_listeners_mixin';
import getCatalogResourceComponentNames from '../../../graphql/queries/get_resource_component_names.query.graphql';

export default {
  name: 'ComponentNameToken',
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
      components: [],
      searchTerm: '',
    };
  },
  apollo: {
    components: {
      query: getCatalogResourceComponentNames,
      variables() {
        return { fullPath: this.config.resourcePath };
      },
      update(data) {
        const nodes = data?.ciCatalogResource?.versions?.nodes?.[0]?.components?.nodes || [];
        return nodes.map((c) => ({ value: c.name, text: c.name }));
      },
      error() {
        createAlert({ message: s__('CiCatalog|There was an error fetching components.') });
      },
    },
  },
  computed: {
    loading() {
      return this.$apollo.queries.components.loading;
    },
    filteredComponents() {
      if (!this.searchTerm) return this.components;
      const term = this.searchTerm.toLowerCase();
      return this.components.filter((c) => c.value.toLowerCase().includes(term));
    },
  },
  methods: {
    getActiveTokenValue(suggestions, data) {
      return suggestions.find((s) => s.value === data);
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
    :suggestions="filteredComponents"
    :suggestions-loading="loading"
    :get-active-token-value="getActiveTokenValue"
    v-on="glListeners()"
    @fetch-suggestions="searchTerm = $event"
  >
    <template #view="{ viewTokenProps: { activeTokenValue } }">
      <template v-if="activeTokenValue">{{ activeTokenValue.text }}</template>
    </template>
    <template #suggestions-list="{ suggestions }">
      <gl-filtered-search-suggestion
        v-for="component in suggestions"
        :key="component.value"
        :value="component.value"
      >
        {{ component.text }}
      </gl-filtered-search-suggestion>
    </template>
  </base-token>
</template>
