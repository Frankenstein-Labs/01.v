<script>
import { GlFilteredSearchSuggestion, GlIcon } from '@gitlab/ui';
import { createAlert } from '~/alert';
import { s__ } from '~/locale';
import BaseToken from '~/vue_shared/components/filtered_search_bar/tokens/base_token.vue';
import getCiCatalogResourceVersions from '~/ci/catalog/graphql/queries/get_ci_catalog_resource_versions.query.graphql';
import { glListenersMixin } from '~/lib/utils/vue3compat/gl_listeners_mixin';

export default {
  name: 'VersionToken',
  components: {
    BaseToken,
    GlFilteredSearchSuggestion,
    GlIcon,
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
      versions: [],
      allVersions: [],
      searchTerm: null,
    };
  },
  apollo: {
    versions: {
      query: getCiCatalogResourceVersions,
      variables() {
        return {
          fullPath: this.config.resourcePath,
          search: this.searchTerm,
        };
      },
      skip() {
        return this.searchTerm === null;
      },
      update(data) {
        return (data?.ciCatalogResource?.versions?.nodes || []).map((v) => ({
          value: v.id,
          text: v.name,
        }));
      },
      result({ data }) {
        if (!data?.ciCatalogResource?.versions?.nodes) return;
        this.updateAllVersions(this.versions);
      },
      error() {
        createAlert({ message: s__('CiCatalog|There was an error fetching versions.') });
      },
    },
  },
  computed: {
    loading() {
      return this.$apollo.queries.versions.loading;
    },
    versionNameMap() {
      return Object.fromEntries(this.allVersions.map((v) => [v.value, v.text]));
    },
  },
  methods: {
    updateAllVersions(versions) {
      versions.forEach((version) => {
        if (!this.allVersions.some((v) => v.value === version.value)) {
          this.allVersions.push(version);
        }
      });
    },
    getActiveTokenValue(suggestions, data) {
      return (
        suggestions.find((s) => s.value === data) || this.allVersions.find((v) => v.value === data)
      );
    },
    selectedTokensText(selectedIds) {
      return selectedIds.map((id) => this.versionNameMap[id] || id).join(', ');
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
    :suggestions="versions"
    :suggestions-loading="loading"
    :get-active-token-value="getActiveTokenValue"
    v-on="glListeners()"
    @fetch-suggestions="searchTerm = $event"
  >
    <template #view="{ viewTokenProps: { activeTokenValue, selectedTokens } }">
      <template v-if="selectedTokens.length > 0">{{ selectedTokensText(selectedTokens) }}</template>
      <template v-else-if="activeTokenValue">{{ activeTokenValue.text }}</template>
    </template>
    <template #suggestions-list="{ suggestions, selections = [] }">
      <gl-filtered-search-suggestion
        v-for="version in suggestions"
        :key="version.value"
        :value="version.value"
      >
        <div
          class="gl-flex gl-items-center"
          :class="{ 'gl-pl-6': !selections.includes(version.value) }"
        >
          <gl-icon
            v-if="selections.includes(version.value)"
            name="check"
            class="gl-mr-3 gl-shrink-0"
            variant="subtle"
          />
          {{ version.text }}
        </div>
      </gl-filtered-search-suggestion>
    </template>
  </base-token>
</template>
