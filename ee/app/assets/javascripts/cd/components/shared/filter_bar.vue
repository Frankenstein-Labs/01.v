<script>
import { GlBadge, GlButton, GlButtonGroup, GlSearchBoxByType } from '@gitlab/ui';
import { debounce } from 'lodash-es';
import { s__ } from '~/locale';
import { DEFAULT_DEBOUNCE_AND_THROTTLE_MS } from '~/lib/utils/constants';

export default {
  name: 'FilterBar',
  components: {
    GlBadge,
    GlButton,
    GlButtonGroup,
    GlSearchBoxByType,
  },
  props: {
    filters: {
      type: Array,
      required: true,
      // Array of { id: String, text: String, count: Number }, e.g. { id: 'ALL', text: 'All', count: 1 }
    },
    selectedFilterId: {
      type: String,
      required: false,
      default: null,
    },
    searchTerm: {
      type: String,
      required: false,
      default: '',
    },
    searchPlaceholder: {
      type: String,
      required: false,
      default: () => s__('ContinuousDeployment|Filter applications...'),
    },
    searchFirst: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  emits: ['search', 'filter-selected'],
  data() {
    return {
      // Local copy so the input stays responsive while we debounce the emit.
      localSearchTerm: this.searchTerm,
    };
  },
  computed: {
    activeFilterId() {
      // Fall back to the first filter when the parent has not selected one.
      return this.selectedFilterId ?? this.filters[0]?.id ?? null;
    },
    searchBoxAttributes() {
      return {
        value: this.localSearchTerm,
        placeholder: this.searchPlaceholder,
        'aria-label': this.searchPlaceholder,
        class: 'gl-grow',
        'data-testid': 'filter-search',
      };
    },
  },
  watch: {
    searchTerm(value) {
      this.localSearchTerm = value;
    },
  },
  created() {
    this.debouncedSearch = debounce((value) => {
      this.$emit('search', value);
    }, DEFAULT_DEBOUNCE_AND_THROTTLE_MS);
  },
  beforeDestroy() {
    this.debouncedSearch.cancel();
  },
  methods: {
    selectFilter(id) {
      if (id === this.activeFilterId) return;
      this.$emit('filter-selected', id);
    },
    onSearchInput(value) {
      this.localSearchTerm = value;
      this.debouncedSearch(value);
    },
  },
};
</script>

<template>
  <div class="gl-flex gl-flex-wrap gl-gap-3 @lg:gl-flex-nowrap">
    <!-- searchFirst decides whether the search box renders before or after the filters, keeping DOM order in sync with tab order. -->
    <gl-search-box-by-type v-if="searchFirst" v-bind="searchBoxAttributes" @input="onSearchInput" />
    <gl-button-group class="gl-max-w-full">
      <gl-button
        v-for="filter in filters"
        :key="filter.id"
        :selected="filter.id === activeFilterId"
        :data-testid="`filter-button-${filter.id}`"
        @click="selectFilter(filter.id)"
      >
        {{ filter.text }}
        <gl-badge v-if="filter.count >= 0" class="gl-ml-2">{{ filter.count }}</gl-badge>
      </gl-button>
    </gl-button-group>
    <gl-search-box-by-type
      v-if="!searchFirst"
      v-bind="searchBoxAttributes"
      @input="onSearchInput"
    />
  </div>
</template>
