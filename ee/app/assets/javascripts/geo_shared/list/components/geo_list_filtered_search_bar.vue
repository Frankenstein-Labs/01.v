<script>
import { GlCollapsibleListbox, GlSorting } from '@gitlab/ui';
import { SORT_DIRECTION } from 'ee/geo_shared/constants';
import GeoListFilteredSearch from './geo_list_filtered_search.vue';

export default {
  name: 'GeoListFilteredSearchBar',
  components: {
    GlCollapsibleListbox,
    GlSorting,
    GeoListFilteredSearch,
  },
  inject: {
    listboxItems: {
      type: Array,
      default: [],
    },
    sortOptions: {
      default: [],
    },
  },
  props: {
    listboxHeaderText: {
      type: String,
      required: true,
    },
    activeListboxItem: {
      type: String,
      required: true,
    },
    activeFilteredSearchFilters: {
      type: Array,
      required: false,
      default: () => [],
    },
    filteredSearchOptionLabel: {
      type: String,
      required: false,
      default: '',
    },
    activeSort: {
      type: Object,
      required: true,
      validator: (item) =>
        ['value', 'direction'].every((key) => Object.prototype.hasOwnProperty.call(item, key)),
    },
  },
  emits: ['listbox-change', 'search', 'sort'],
  data() {
    return {
      listboxSearch: '',
    };
  },
  computed: {
    filteredListboxItems() {
      return this.listboxItems.filter(
        (item) =>
          item.text.toLowerCase().includes(this.listboxSearch.toLowerCase()) ||
          item.value === this.activeListboxItem,
      );
    },
    listboxItem: {
      get() {
        return this.activeListboxItem;
      },
      set(val) {
        this.$emit('listbox-change', val);
      },
    },
    sortIsAscending() {
      return this.activeSort.direction === SORT_DIRECTION.ASC;
    },
  },
  methods: {
    handleListboxSearch(search) {
      this.listboxSearch = search;
    },
    handleSearch(val) {
      this.$emit('search', val);
    },
    handleSortChange(value) {
      this.$emit('sort', { value, direction: this.activeSort.direction });
    },
    handleSortDirectionChange(ascending) {
      const direction = ascending ? SORT_DIRECTION.ASC : SORT_DIRECTION.DESC;
      this.$emit('sort', { value: this.activeSort.value, direction });
    },
  },
};
</script>

<template>
  <div class="row-content-block">
    <div
      class="gl-flex gl-grow gl-flex-col gl-border-t-0 @sm/panel:gl-flex @sm/panel:gl-flex-row @sm/panel:gl-gap-3"
    >
      <label id="listbox-select-label" class="gl-sr-only">{{ listboxHeaderText }}</label>
      <gl-collapsible-listbox
        v-model="listboxItem"
        :items="filteredListboxItems"
        :header-text="listboxHeaderText"
        searchable
        toggle-aria-labelled-by="listbox-select-label"
        class="gl-mb-4 @sm/panel:gl-mb-0"
        @search="handleListboxSearch"
      />
      <div class="gl-flex !gl-grow gl-grow gl-flex-col @sm/panel:gl-flex-row @sm/panel:gl-gap-3">
        <geo-list-filtered-search
          :active-filters="activeFilteredSearchFilters"
          :filtered-search-option-label="filteredSearchOptionLabel"
          @search="handleSearch"
        />
        <gl-sorting
          class="gl-max-w-max"
          :sort-by="activeSort.value"
          :is-ascending="sortIsAscending"
          :sort-options="sortOptions"
          @sortDirectionChange="handleSortDirectionChange"
          @sortByChange="handleSortChange"
        />
      </div>
    </div>
  </div>
</template>
