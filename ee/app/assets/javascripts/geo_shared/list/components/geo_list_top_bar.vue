<script>
import { GlIcon } from '@gitlab/ui';
import { __ } from '~/locale';
import PageHeading from '~/vue_shared/components/page_heading.vue';
import GeoListFilteredSearchBar from './geo_list_filtered_search_bar.vue';
import GeoListBulkActions from './geo_list_bulk_actions.vue';

export default {
  name: 'GeoListTopBar',
  components: {
    GlIcon,
    PageHeading,
    GeoListFilteredSearchBar,
    GeoListBulkActions,
  },
  props: {
    pageHeadingTitle: {
      type: String,
      required: true,
    },
    pageHeadingDescription: {
      type: String,
      required: true,
    },
    listCountIcon: {
      type: String,
      required: false,
      default: '',
    },
    listCountText: {
      type: String,
      required: false,
      default: '',
    },
    listboxHeaderText: {
      type: String,
      required: false,
      default: __('Select item'),
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
      required: true,
    },
    showActions: {
      type: Boolean,
      required: false,
      default: false,
    },
    bulkActions: {
      type: Array,
      required: false,
      default: () => [],
    },
    activeSort: {
      type: Object,
      required: true,
    },
  },
  emits: ['bulk-action', 'listbox-change', 'search', 'sort'],
  methods: {
    handleListboxChange(val) {
      this.$emit('listbox-change', val);
    },
    handleSearch(val) {
      this.$emit('search', val);
    },
    handleSort(sort) {
      this.$emit('sort', sort);
    },
    handleBulkAction(action) {
      this.$emit('bulk-action', action);
    },
  },
};
</script>

<template>
  <div>
    <page-heading :heading="pageHeadingTitle">
      <template #actions>
        <geo-list-bulk-actions
          v-if="showActions"
          :bulk-actions="bulkActions"
          @bulk-action="handleBulkAction"
        />
      </template>
      <template #description>
        <div>{{ pageHeadingDescription }}</div>
        <span v-if="listCountText" data-testid="list-count"
          ><gl-icon v-if="listCountIcon" :name="listCountIcon" class="gl-mr-2" />{{
            listCountText
          }}</span
        >
      </template>
    </page-heading>
    <geo-list-filtered-search-bar
      :listbox-header-text="listboxHeaderText"
      :active-listbox-item="activeListboxItem"
      :active-filtered-search-filters="activeFilteredSearchFilters"
      :filtered-search-option-label="filteredSearchOptionLabel"
      :active-sort="activeSort"
      @listbox-change="handleListboxChange"
      @search="handleSearch"
      @sort="handleSort"
    />
  </div>
</template>
