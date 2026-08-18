<script>
import { GlIcon, GlAlert, GlTooltipDirective } from '@gitlab/ui';
import { s__ } from '~/locale';
import { OPERATORS_IS } from '~/vue_shared/components/filtered_search_bar/constants';
import FilteredSearchBar from '~/vue_shared/components/filtered_search_bar/filtered_search_bar_root.vue';
import DateRangeFilter from '~/observability/components/date_range_filter.vue';
import { SORTING_OPTIONS } from '~/observability/constants';
import { isTracingDateRangeOutOfBounds } from '~/observability/utils';
import { nDaysBefore, getCurrentUtcDate } from '~/lib/utils/datetime_utility';
import BaseToken from '~/vue_shared/components/filtered_search_bar/tokens/base_token.vue';
import {
  SERVICE_NAME_FILTER_TOKEN_TYPE,
  OPERATION_FILTER_TOKEN_TYPE,
  TRACE_ID_FILTER_TOKEN_TYPE,
  DURATION_MS_FILTER_TOKEN_TYPE,
  ATTRIBUTE_FILTER_TOKEN_TYPE,
  STATUS_FILTER_TOKEN_TYPE,
  filterObjToFilterToken,
  filterTokensToFilterObj,
  MAX_PERIOD_DAYS,
  PERIOD_FILTER_OPTIONS,
} from './filters';
import ServiceToken from './service_search_token.vue';
import OperationToken from './operation_search_token.vue';
import AttributeSearchToken from './attribute_search_token.vue';
import TracingBaseToken from './tracing_base_search_token.vue';

export default {
  name: 'TracingFilteredSearch',
  components: {
    GlAlert,
    FilteredSearchBar,
    DateRangeFilter,
    GlIcon,
  },
  directives: {
    tooltip: GlTooltipDirective,
  },
  i18n: {
    searchInputPlaceholder: s__('Tracing|Filter traces'),
    dateRangeLimitInfoMessage: s__(
      'Tracing|Time range is currently limited to a maximum of 12 hours.',
    ),
    dateRangeWarningMessage: s__(
      'Tracing|Time range is currently limited to a maximum of 12 hours. Please select a smaller range.',
    ),
  },
  props: {
    attributesFilters: {
      type: Object,
      required: false,
      default: () => {},
    },
    dateRangeFilter: {
      type: Object,
      required: true,
    },
    observabilityClient: {
      required: true,
      type: Object,
    },
    initialSort: {
      required: true,
      type: String,
    },
  },
  emits: ['filter', 'sort'],
  data() {
    return {
      attributesFilterValue: filterObjToFilterToken(this.attributesFilters),
      dateRangeFilterValue: this.dateRangeFilter,
    };
  },
  computed: {
    defaultMinDate() {
      return nDaysBefore(getCurrentUtcDate(), 30, { utc: true });
    },
    sortOptions() {
      return [
        {
          id: 1,
          title: s__('Tracing|Duration'),
          sortDirection: {
            ascending: SORTING_OPTIONS.DURATION_ASC,
            descending: SORTING_OPTIONS.DURATION_DESC,
          },
        },
        {
          id: 2,
          title: s__('Tracing|Timestamp'),
          sortDirection: {
            ascending: SORTING_OPTIONS.TIMESTAMP_ASC,
            descending: SORTING_OPTIONS.TIMESTAMP_DESC,
          },
        },
      ];
    },
    availableTokens() {
      return [
        {
          title: s__('Tracing|Service'),
          type: SERVICE_NAME_FILTER_TOKEN_TYPE,
          token: ServiceToken,
          operators: OPERATORS_IS,
          fetchServices: this.observabilityClient.fetchServices,
        },
        {
          title: s__('Tracing|Operation'),
          type: OPERATION_FILTER_TOKEN_TYPE,
          token: OperationToken,
          operators: OPERATORS_IS,
          fetchOperations: this.observabilityClient.fetchOperations,
        },
        {
          title: s__('Tracing|Trace ID'),
          type: TRACE_ID_FILTER_TOKEN_TYPE,
          token: BaseToken,
          operators: OPERATORS_IS,
          suggestionsDisabled: true,
        },
        {
          title: s__('Tracing|Duration (ms)'),
          type: DURATION_MS_FILTER_TOKEN_TYPE,
          token: TracingBaseToken,
          operators: [
            { value: '>', description: s__('Tracing|longer than') },
            { value: '<', description: s__('Tracing|shorter than') },
          ],
        },
        {
          title: s__('Tracing|Attribute'),
          type: ATTRIBUTE_FILTER_TOKEN_TYPE,
          token: AttributeSearchToken,
          operators: OPERATORS_IS,
        },
        {
          title: s__('Tracing|Status'),
          type: STATUS_FILTER_TOKEN_TYPE,
          token: TracingBaseToken,
          operators: OPERATORS_IS,
          options: [
            { value: 'ok', title: s__('Tracing|Ok') },
            { value: 'error', title: s__('Tracing|Error') },
          ],
        },
      ];
    },
    dateRangeValid() {
      return !isTracingDateRangeOutOfBounds(this.dateRangeFilterValue);
    },
  },
  methods: {
    onAttributesFilters(attributesFilters) {
      this.attributesFilterValue = attributesFilters;
      this.submitFilter();
    },
    handleDateRangeSelected(dateRangeFilter) {
      this.dateRangeFilterValue = dateRangeFilter;
      if (this.dateRangeValid) {
        this.submitFilter();
      }
    },
    submitFilter() {
      this.$emit('filter', {
        attributes: filterTokensToFilterObj(this.attributesFilterValue),
        dateRange: this.dateRangeFilterValue,
      });
    },
  },
  MAX_PERIOD_DAYS,
  PERIOD_FILTER_OPTIONS,
};
</script>

<template>
  <div
    class="gl-border-b-1 gl-border-t-1 gl-border-default gl-bg-subtle gl-px-3 gl-py-5 gl-border-b-solid gl-border-t-solid"
  >
    <filtered-search-bar
      recent-searches-storage-key="recent-tracing-filter-search"
      :initial-sort-by="initialSort"
      namespace="tracing-list-filtered-search"
      :search-input-placeholder="$options.i18n.searchInputPlaceholder"
      :tokens="availableTokens"
      :initial-filter-value="attributesFilterValue"
      terms-as-tokens
      :sort-options="sortOptions"
      sync-filter-and-sort
      @on-filter="onAttributesFilters"
      @on-sort="$emit('sort', $event)"
    />

    <hr class="gl-my-3" />

    <div class="gl-flex gl-gap-3">
      <date-range-filter
        :selected="dateRangeFilterValue"
        :max-date-range="2"
        :default-min-date="defaultMinDate"
        :date-options="$options.PERIOD_FILTER_OPTIONS"
        :date-time-range-picker-state="dateRangeValid"
        @on-date-range-selected="handleDateRangeSelected"
      />

      <div class="gl-self-center">
        <gl-icon
          v-tooltip="$options.i18n.dateRangeLimitInfoMessage"
          name="information-o"
          :size="16"
          variant="subtle"
        />
      </div>
    </div>

    <gl-alert v-if="!dateRangeValid" variant="danger" class="gl-my-3" :dismissible="false">{{
      $options.i18n.dateRangeWarningMessage
    }}</gl-alert>
  </div>
</template>
