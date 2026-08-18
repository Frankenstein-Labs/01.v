<script>
import { GlFilteredSearchToken, GlButton, GlLoadingIcon } from '@gitlab/ui';

import { s__ } from '~/locale';
import { OPERATORS_IS_NOT } from '~/vue_shared/components/filtered_search_bar/constants';
import FilteredSearchBar from '~/vue_shared/components/filtered_search_bar/filtered_search_bar_root.vue';
import { OPERATORS_LIKE_NOT } from '~/observability/constants';
import DateRangeFilter from '~/observability/components/date_range_filter.vue';
import { isHistogram } from '../utils';
import GroupByFilter from './groupby_filter.vue';

function defaultGroupByFunction(searchMetadata) {
  let defaultFunction;
  if (searchMetadata.supported_functions.includes(searchMetadata.default_group_by_function)) {
    defaultFunction = searchMetadata.default_group_by_function;
  }
  return defaultFunction;
}
function defaultGroupByAttributes(searchMetadata) {
  let defaultAttributes = (searchMetadata.default_group_by_attributes ?? []).filter(
    (attribute) => attribute === '*' || searchMetadata.attribute_keys.includes(attribute),
  );
  if (defaultAttributes.length === 1 && defaultAttributes[0] === '*') {
    defaultAttributes = [...(searchMetadata.attribute_keys ?? [])];
  }
  return defaultAttributes;
}

export default {
  name: 'MetricsFilteredSearch',
  components: {
    FilteredSearchBar,
    DateRangeFilter,
    GroupByFilter,
    GlButton,
    GlLoadingIcon,
  },
  i18n: {
    searchInputPlaceholder: s__('ObservabilityMetrics|Filter dimensions…'),
    search: s__('ObservabilityMetrics|Search'),
    cancel: s__('ObservabilityMetrics|Cancel'),
  },
  props: {
    searchMetadata: {
      type: Object,
      required: true,
    },
    attributeFilters: {
      type: Array,
      required: false,
      default: () => [],
    },
    dateRangeFilter: {
      type: Object,
      required: false,
      default: () => {},
    },
    groupByFilter: {
      type: Object,
      required: false,
      default: () => {},
    },
    loading: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  emits: ['cancel', 'submit'],
  data() {
    return {
      filters: this.attributeFilters,
      dateRange: this.dateRangeFilter,
      groupBy: {
        attributes: this.groupByFilter?.attributes ?? defaultGroupByAttributes(this.searchMetadata),
        func: this.groupByFilter?.func ?? defaultGroupByFunction(this.searchMetadata),
      },
    };
  },
  computed: {
    availableTokens() {
      return this.searchMetadata.attribute_keys.map((attribute) => ({
        title: attribute,
        type: attribute,
        token: GlFilteredSearchToken,
        operators: [...OPERATORS_IS_NOT, ...OPERATORS_LIKE_NOT],
      }));
    },
    showGroupByFilter() {
      const metricType = this.searchMetadata.type;
      return !isHistogram(metricType);
    },
  },
  methods: {
    onFilter(filters) {
      this.filters = filters;
    },
    onInput(filters) {
      // on input event filters might be incomplete
      this.filters = filters.filter(({ value }) => value.data && value.operator);
    },
    handleDateRangeSelected({ value, startDate, endDate }) {
      this.dateRange = { value, startDate, endDate };
    },
    onGroupBy({ attributes, func }) {
      this.groupBy = { attributes, func };
    },
    onSubmit() {
      if (this.loading) {
        this.$emit('cancel');
      } else {
        this.$emit('submit', {
          attributes: this.filters,
          dateRange: this.dateRange,
          groupBy: this.groupBy,
        });
      }
    },
  },
};
</script>

<template>
  <div
    class="gl-mb-6 gl-mt-3 gl-border-b-1 gl-border-t-1 gl-border-default gl-bg-subtle gl-px-3 gl-py-5 gl-border-b-solid gl-border-t-solid"
  >
    <filtered-search-bar
      class="filtered-search-box gl-flex gl-border-none"
      recent-searches-storage-key="recent-metrics-filter-search"
      namespace="metrics-details-filtered-search"
      :search-input-placeholder="$options.i18n.searchInputPlaceholder"
      :tokens="availableTokens"
      :initial-filter-value="filters"
      terms-as-tokens
      :show-search-button="false"
      @on-filter="onFilter"
      @on-input="onInput"
    />

    <hr class="gl-my-3" />

    <date-range-filter :selected="dateRange" @on-date-range-selected="handleDateRangeSelected" />

    <div v-if="showGroupByFilter">
      <hr class="gl-my-3" />

      <group-by-filter
        :supported-functions="searchMetadata.supported_functions"
        :supported-attributes="searchMetadata.attribute_keys"
        :selected-attributes="groupBy.attributes"
        :selected-function="groupBy.func"
        @group-by="onGroupBy"
      />
    </div>

    <gl-button
      type="submit"
      :variant="loading ? 'danger' : 'confirm'"
      class="gl-my-5 !gl-mb-0"
      @click="onSubmit"
    >
      <template v-if="loading">
        <gl-loading-icon size="sm" inline color="light" />
        {{ $options.i18n.cancel }}
      </template>
      <template v-else>
        {{ $options.i18n.search }}
      </template>
    </gl-button>
  </div>
</template>
