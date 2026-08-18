<script>
import { GlCollapsibleListbox } from '@gitlab/ui';
import { uniqueId } from 'lodash-es';
import {
  REPOSITORY_FORMAT_ALL,
  REPOSITORY_FORMAT_FILTER_OPTIONS,
  REPOSITORY_KIND_TOKEN,
  REPOSITORY_KIND_TOKEN_TYPE,
} from 'ee/packages_and_registries/artifact_registry/constants';
import { s__ } from '~/locale';
import { OPERATOR_IS } from '~/vue_shared/components/filtered_search_bar/constants';
import FilteredSearchBarRoot from '~/vue_shared/components/filtered_search_bar/filtered_search_bar_root.vue';

export default {
  name: 'ArtifactRegistryRepositoriesToolbar',
  components: {
    FilteredSearchBarRoot,
    GlCollapsibleListbox,
  },
  inject: ['organizationGid'],
  props: {
    filters: {
      type: Object,
      required: true,
    },
  },
  emits: ['apply-filter'],
  data() {
    return {
      formatLabelId: uniqueId('artifact-registry-format-filter-'),
    };
  },
  computed: {
    selectedFormat() {
      return this.filters.format ?? REPOSITORY_FORMAT_ALL;
    },
    initialFilterValue() {
      if (!this.filters.kind) {
        return [];
      }

      return [
        {
          type: REPOSITORY_KIND_TOKEN_TYPE,
          value: { data: this.filters.kind, operator: OPERATOR_IS },
        },
      ];
    },
  },
  methods: {
    selectFormat(format) {
      this.$emit('apply-filter', {
        ...this.filters,
        format: format === REPOSITORY_FORMAT_ALL ? null : format,
      });
    },
    applyTokens(tokens) {
      // The bar also emits the free-text term it collects, which the list endpoint does
      // not honor, so only the Type token reaches the filters.
      const kindToken = tokens.find(({ type }) => type === REPOSITORY_KIND_TOKEN_TYPE);
      const kind = kindToken?.value?.data ?? null;

      this.$emit('apply-filter', { ...this.filters, kind });
    },
  },
  formatOptions: REPOSITORY_FORMAT_FILTER_OPTIONS,
  tokens: [REPOSITORY_KIND_TOKEN],
  i18n: {
    formatLabel: s__('ArtifactRegistry|Format'),
    searchInputPlaceholder: s__('ArtifactRegistry|Filter repositories'),
  },
};
</script>

<template>
  <div class="gl-flex gl-flex-col gl-gap-3 gl-border-y-0 gl-bg-subtle gl-p-5 @md/panel:gl-flex-row">
    <!-- `sync-filter-and-sort` ungates the bar's re-sync watcher, without which a
         selection the bar did not raise never reaches its rendered tokens. -->
    <filtered-search-bar-root
      class="gl-min-w-0 gl-grow"
      :namespace="organizationGid"
      :tokens="$options.tokens"
      :initial-filter-value="initialFilterValue"
      :search-input-placeholder="$options.i18n.searchInputPlaceholder"
      sync-filter-and-sort
      @on-filter="applyTokens"
    />

    <span :id="formatLabelId" class="gl-sr-only">{{ $options.i18n.formatLabel }}</span>
    <gl-collapsible-listbox
      :items="$options.formatOptions"
      :selected="selectedFormat"
      :toggle-aria-labelled-by="formatLabelId"
      @select="selectFormat"
    />
  </div>
</template>
