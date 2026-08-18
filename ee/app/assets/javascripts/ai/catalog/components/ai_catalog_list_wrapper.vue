<script>
import FilteredSearchBar from '~/vue_shared/components/filtered_search_bar/filtered_search_bar_root.vue';
import {
  filterToQueryObject,
  processFilters,
} from '~/vue_shared/components/filtered_search_bar/filtered_search_utils';
import { FILTERED_SEARCH_TERM } from '~/vue_shared/components/filtered_search_bar/constants';
import { s__ } from '~/locale';
import {
  AI_CATALOG_FILTERED_SEARCH_NAMESPACE,
  AI_CATALOG_FILTERED_SEARCH_TERM_KEY,
  RECENT_SEARCHES_STORAGE_KEY_AI_CATALOG,
  SORT_OPTIONS,
} from '../constants';
import AiCatalogList from './ai_catalog_list.vue';

export default {
  name: 'AiCatalogListWrapper',
  components: {
    AiCatalogList,
    FilteredSearchBar,
  },
  props: {
    items: {
      type: Array,
      required: true,
    },
    isLoading: {
      type: Boolean,
      required: false,
      default: false,
    },
    pageInfo: {
      type: Object,
      required: true,
    },
    itemTypeConfig: {
      type: Object,
      required: true,
      validator(item) {
        return item.showRoute && item.visibilityTooltip;
      },
    },
    emptyStateTitle: {
      type: String,
      required: false,
      default: s__('AICatalog|Get started with the AI Catalog'),
    },
    emptyStateDescription: {
      type: String,
      required: false,
      default: s__(
        'AICatalog|Build agents and flows to automate tasks and solve complex problems.',
      ),
    },
    emptyStateButtonHref: {
      type: String,
      required: false,
      default: null,
    },
    emptyStateButtonText: {
      type: String,
      required: false,
      default: null,
    },
    searchTerm: {
      type: String,
      required: false,
      default: '',
    },
    disabledItemTypeMessages: {
      type: Array,
      required: false,
      default: () => [],
    },
    // Full sort string fed to FilteredSearchBar's `initial-sort-by` (e.g. 'STAR_COUNT_DESC').
    // An empty string means the directionless default (CATALOG_PRIORITY), which suppresses
    // the direction toggle via sortDirectionToggleClass.
    initialSortBy: {
      type: String,
      required: false,
      default: '',
    },
  },
  emits: ['filter', 'sort', 'empty-state-click', 'next-page', 'prev-page'],
  computed: {
    showSearchAndSort() {
      return this.isLoading || this.items.length > 0 || Boolean(this.searchTerm);
    },
    sortDirectionToggleClass() {
      // `initialSortBy` is '' when the current sort is directionless (CATALOG_PRIORITY).
      // Callers derive this via `sortingComputeds.initialSortBy`, which maps CATALOG_PRIORITY
      // to '' before passing it to this component, so this prop never receives the literal
      // string 'CATALOG_PRIORITY'.
      //
      // The visual-only suppression (pointer-events + opacity) is a known a11y gap:
      // the button remains focusable and announced as interactive to screen readers.
      // A first-class `disabled` prop on GlSorting is tracked at:
      // https://gitlab.com/gitlab-org/gitlab-services/design.gitlab.com/-/work_items/2712
      return this.initialSortBy === '' ? 'gl-pointer-events-none gl-opacity-50' : '';
    },
    initialFilterValue() {
      return this.searchTerm
        ? [{ type: FILTERED_SEARCH_TERM, value: { data: this.searchTerm } }]
        : [];
    },
  },
  methods: {
    handleFilter(filters) {
      this.$emit(
        'filter',
        filterToQueryObject(processFilters(filters), {
          filteredSearchTermKey: AI_CATALOG_FILTERED_SEARCH_TERM_KEY,
          shouldExcludeEmpty: true,
        }),
      );
    },
    handleSort(sortValue) {
      this.$emit('sort', sortValue);
    },
  },
  RECENT_SEARCHES_STORAGE_KEY_AI_CATALOG,
  AI_CATALOG_FILTERED_SEARCH_NAMESPACE,
  SORT_OPTIONS,
  EMPTY_TOKENS: [],
};
</script>

<template>
  <div>
    <div v-if="showSearchAndSort" class="gl-border-b gl-bg-subtle gl-p-5">
      <filtered-search-bar
        :namespace="$options.AI_CATALOG_FILTERED_SEARCH_NAMESPACE"
        :tokens="$options.EMPTY_TOKENS"
        :initial-filter-value="initialFilterValue"
        :recent-searches-storage-key="$options.RECENT_SEARCHES_STORAGE_KEY_AI_CATALOG"
        :sort-options="$options.SORT_OPTIONS"
        :initial-sort-by="initialSortBy"
        :sort-direction-toggle-class="sortDirectionToggleClass"
        sync-filter-and-sort
        terms-as-tokens
        @on-filter="handleFilter"
        @on-sort="handleSort"
      />
    </div>

    <ai-catalog-list
      :is-loading="isLoading"
      :items="items"
      :item-type-config="itemTypeConfig"
      :page-info="pageInfo"
      :search="searchTerm"
      :disabled-item-type-messages="disabledItemTypeMessages"
      :empty-state-title="emptyStateTitle"
      :empty-state-description="emptyStateDescription"
      :empty-state-button-href="emptyStateButtonHref"
      :empty-state-button-text="emptyStateButtonText"
      @empty-state-click="$emit('empty-state-click')"
      @next-page="$emit('next-page')"
      @prev-page="$emit('prev-page')"
    />
  </div>
</template>
