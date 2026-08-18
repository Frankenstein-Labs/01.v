<script>
import { GlFilteredSearchToken } from '@gitlab/ui';
import FilteredSearchBar from '~/vue_shared/components/filtered_search_bar/filtered_search_bar_root.vue';
import DateRangeFilter from '~/observability/components/date_range_filter.vue';
import { s__ } from '~/locale';
import {
  OPERATORS_IS_NOT,
  OPERATORS_IS,
} from '~/vue_shared/components/filtered_search_bar/constants';
import { DEFAULT_SEVERITY_LEVELS } from '../../utils';
import {
  SERVICE_NAME_FILTER_TOKEN_TYPE,
  SEVERITY_NAME_FILTER_TOKEN_TYPE,
  SEVERITY_NUMBER_FILTER_TOKEN_TYPE,
  TRACE_ID_FILTER_TOKEN_TYPE,
  SPAN_ID_FILTER_TOKEN_TYPE,
  FINGERPRINT_FILTER_TOKEN_TYPE,
  TRACE_FLAGS_FILTER_TOKEN_TYPE,
  ATTRIBUTE_FILTER_TOKEN_TYPE,
  RESOURCE_ATTRIBUTE_FILTER_TOKEN_TYPE,
  filterTokensToFilterObj,
  filterObjToFilterToken,
} from './filters';
import AttributeSearchToken from './attribute_search_token.vue';

const toOptions = (values) =>
  values.map((value) => ({
    value,
    title: value,
  }));

export default {
  components: {
    DateRangeFilter,
    FilteredSearchBar,
  },
  props: {
    dateRangeFilter: {
      type: Object,
      required: true,
    },
    attributesFilters: {
      type: Object,
      required: false,
      default: () => {},
    },
    searchMetadata: {
      type: Object,
      required: false,
      default: () => {},
    },
  },
  emits: ['filter'],
  i18n: {
    searchInputPlaceholder: s__('ObservabilityLogs|Search logs…'),
  },
  data() {
    return {
      attributesFilterValue: filterObjToFilterToken(this.attributesFilters),
      dateRangeFilterValue: this.dateRangeFilter,
    };
  },
  computed: {
    availableTokens() {
      const severityNameOptions = this.searchMetadata?.severity_names || DEFAULT_SEVERITY_LEVELS;
      const traceFlagOptions = this.searchMetadata?.trace_flags || [];
      const serviceNameOptions = this.searchMetadata?.service_names || [];
      return [
        {
          title: s__('ObservabilityLogs|Service'),
          type: SERVICE_NAME_FILTER_TOKEN_TYPE,
          token: GlFilteredSearchToken,
          operators: OPERATORS_IS_NOT,
          options: toOptions(serviceNameOptions),
        },
        {
          title: s__('ObservabilityLogs|Severity'),
          type: SEVERITY_NAME_FILTER_TOKEN_TYPE,
          token: GlFilteredSearchToken,
          operators: OPERATORS_IS_NOT,
          options: toOptions(severityNameOptions),
        },
        {
          title: s__('ObservabilityLogs|Severity Number'),
          type: SEVERITY_NUMBER_FILTER_TOKEN_TYPE,
          token: GlFilteredSearchToken,
          operators: OPERATORS_IS_NOT,
        },
        {
          title: s__('ObservabilityLogs|Trace ID'),
          type: TRACE_ID_FILTER_TOKEN_TYPE,
          token: GlFilteredSearchToken,
          operators: OPERATORS_IS,
        },
        {
          title: s__('ObservabilityLogs|Span ID'),
          type: SPAN_ID_FILTER_TOKEN_TYPE,
          token: GlFilteredSearchToken,
          operators: OPERATORS_IS,
        },
        {
          title: s__('ObservabilityLogs|Fingerprint'),
          type: FINGERPRINT_FILTER_TOKEN_TYPE,
          token: GlFilteredSearchToken,
          operators: OPERATORS_IS,
        },
        {
          title: s__('ObservabilityLogs|Trace Flags'),
          type: TRACE_FLAGS_FILTER_TOKEN_TYPE,
          token: GlFilteredSearchToken,
          operators: OPERATORS_IS_NOT,
          options: toOptions(traceFlagOptions),
        },
        {
          title: s__('ObservabilityLogs|Attribute'),
          type: ATTRIBUTE_FILTER_TOKEN_TYPE,
          token: AttributeSearchToken,
          operators: OPERATORS_IS,
        },
        {
          title: s__('ObservabilityLogs|Resource Attribute'),
          type: RESOURCE_ATTRIBUTE_FILTER_TOKEN_TYPE,
          token: AttributeSearchToken,
          operators: OPERATORS_IS,
        },
      ];
    },
  },
  methods: {
    handleDateRangeSelected({ value, startDate, endDate }) {
      this.dateRangeFilterValue = { value, startDate, endDate };
      this.submitFilter();
    },
    onAttributesFilters(attributesFilters) {
      this.attributesFilterValue = attributesFilters;
      this.submitFilter();
    },
    submitFilter() {
      this.$emit('filter', {
        dateRange: this.dateRangeFilterValue,
        attributes: filterTokensToFilterObj(this.attributesFilterValue),
      });
    },
  },
};
</script>

<template>
  <div
    class="gl-border-b-1 gl-border-t-1 gl-border-default gl-bg-subtle gl-px-3 gl-py-5 gl-border-b-solid gl-border-t-solid"
  >
    <filtered-search-bar
      class="filtered-search-box gl-flex gl-border-none"
      recent-searches-storage-key="recent-logs-filter-search"
      namespace="logs-details-filtered-search"
      :search-input-placeholder="$options.i18n.searchInputPlaceholder"
      :tokens="availableTokens"
      :initial-filter-value="attributesFilterValue"
      terms-as-tokens
      @on-filter="onAttributesFilters"
    />

    <hr class="gl-my-3" />

    <date-range-filter
      :selected="dateRangeFilterValue"
      @on-date-range-selected="handleDateRangeSelected"
    />
  </div>
</template>
