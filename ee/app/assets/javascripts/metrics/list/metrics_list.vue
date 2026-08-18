<script>
import {
  GlLoadingIcon,
  GlInfiniteScroll,
  GlFilteredSearchToken,
  GlLink,
  GlSprintf,
} from '@gitlab/ui';
import { OPERATORS_IS } from '~/vue_shared/components/filtered_search_bar/constants';
import { s__ } from '~/locale';
import { createAlert } from '~/alert';
import { visitUrl, joinPaths, setUrlParams } from '~/lib/utils/url_utility';
import { DOCS_URL } from '~/constants';
import { isMetaClick, contentTop } from '~/lib/utils/common_utils';
import { sanitize } from '~/lib/dompurify';
import FilteredSearchBar from '~/vue_shared/components/filtered_search_bar/filtered_search_bar_root.vue';
import UrlSync from '~/vue_shared/components/url_sync.vue';
import { logError } from '~/lib/logger';
import PageHeading from '~/vue_shared/components/page_heading.vue';
import ObservabilityNoDataEmptyState from '~/observability/components/observability_no_data_empty_state.vue';
import { InternalEvents } from '~/tracking';
import { metricsDetailsQueryFromAttributes } from 'ee/metrics/details/filters';
import { convertNanoToMs } from '~/lib/utils/datetime_utility';
import { VIEW_METRICS_PAGE } from '../events';
import {
  queryToFilterObj,
  filterObjToQuery,
  filterObjToFilterToken,
  filterTokensToFilterObj,
  ATTRIBUTE_FILTER_TOKEN_TYPE,
  TRACE_ID_FILTER_TOKEN_TYPE,
} from './filters';
import MetricsTable from './metrics_table.vue';

const LIST_VERTICAL_PADDING = 130; // search bar height + some more v padding
const LIST_SEARCH_LIMIT = 50;

export default {
  name: 'MetricsList',
  components: {
    PageHeading,
    GlLoadingIcon,
    MetricsTable,
    GlInfiniteScroll,
    FilteredSearchBar,
    UrlSync,
    GlLink,
    GlSprintf,
    ObservabilityNoDataEmptyState,
  },
  mixins: [InternalEvents.mixin()],
  i18n: {
    searchInputPlaceholder: s__('ObservabilityMetrics|Search metrics…'),
    pageTitle: s__(`ObservabilityMetrics|Metrics`),
    description: s__(
      `ObservabilityMetrics|Track health data from your systems. Send metric data to this project using OpenTelemetry. %{docsLink}`,
    ),
    docsLinkText: s__(`ObservabilityMetrics|Learn more.`),
  },
  docsLink: `${DOCS_URL}/development/metrics`,
  props: {
    observabilityClient: {
      required: true,
      type: Object,
    },
  },
  data() {
    return {
      loading: false,
      metrics: [],
      allAttributes: [],
      filters: queryToFilterObj(window.location.search),
    };
  },
  computed: {
    listHeight() {
      return window.innerHeight - contentTop() - LIST_VERTICAL_PADDING;
    },
    query() {
      return filterObjToQuery(this.filters);
    },
    initialFilterValue() {
      return filterObjToFilterToken(this.filters);
    },
    availableAttributes() {
      return this.allAttributes.map((attribute) => ({
        value: attribute,
        title: attribute,
      }));
    },
    tokens() {
      return [
        {
          title: s__('ObservabilityMetrics|Dimension'),
          type: ATTRIBUTE_FILTER_TOKEN_TYPE,
          token: GlFilteredSearchToken,
          operators: OPERATORS_IS,
          options: this.availableAttributes,
        },
        {
          title: s__('ObservabilityMetrics|Trace ID'),
          type: TRACE_ID_FILTER_TOKEN_TYPE,
          token: GlFilteredSearchToken,
          operators: OPERATORS_IS,
          unique: true,
        },
      ];
    },
  },
  created() {
    this.fetchMetrics();
  },
  mounted() {
    this.trackEvent(VIEW_METRICS_PAGE);
  },
  methods: {
    async fetchMetrics() {
      this.loading = true;
      try {
        const { metrics, all_available_attributes: allAttributes = [] } =
          await this.observabilityClient.fetchMetrics({
            filters: this.filters,
            limit: LIST_SEARCH_LIMIT,
          });
        this.metrics = metrics;
        this.allAttributes = allAttributes;
      } catch (e) {
        createAlert({
          message: s__('ObservabilityMetrics|Failed to load metrics.'),
        });
      } finally {
        this.loading = false;
      }
    },
    onMetricClicked({ metricId, clickEvent = {} }) {
      const external = isMetaClick(clickEvent);
      const metric = this.metrics.find((m) => m.name === metricId);
      if (!metric) {
        logError(new Error(`onMetricClicked() - Could not find ${metricId}`));
        return;
      }
      const { type: metricType, timestamp_of_datapoint_with_traceId: traceIdTimestampNano } =
        metric;

      const traceIdTimestampMs = convertNanoToMs(traceIdTimestampNano);
      const traceIdTimestampIntervalDeltaMs = 60 * 1000; // 1min

      const query = traceIdTimestampNano
        ? metricsDetailsQueryFromAttributes({
            dateRange: {
              startDate: new Date(traceIdTimestampMs - traceIdTimestampIntervalDeltaMs),
              endDate: new Date(traceIdTimestampMs + traceIdTimestampIntervalDeltaMs),
            },
          })
        : {};

      const url = joinPaths(
        window.location.origin,
        window.location.pathname,
        encodeURIComponent(metricId),
      );
      const fullUrl = setUrlParams({ type: encodeURIComponent(metricType), ...query }, { url });
      visitUrl(sanitize(fullUrl), external);
    },
    onFilter(filterTokens) {
      this.filters = filterTokensToFilterObj(filterTokens);
      this.metrics = [];
      this.allAttributes = [];

      this.fetchMetrics();
    },
  },
};
</script>

<template>
  <div class="gl-mx-6">
    <url-sync :query="query" />

    <header>
      <page-heading :heading="$options.i18n.pageTitle">
        <template #description>
          <gl-sprintf :message="$options.i18n.description">
            <template #docsLink>
              <gl-link target="_blank" :href="$options.docsLink">
                <span>{{ $options.i18n.docsLinkText }}</span>
              </gl-link>
            </template>
          </gl-sprintf>
        </template>
      </page-heading>
    </header>

    <div
      class="gl-mt-3 gl-border-b-1 gl-border-t-1 gl-border-default gl-bg-subtle gl-px-3 gl-py-5 gl-border-b-solid gl-border-t-solid"
    >
      <filtered-search-bar
        :initial-filter-value="initialFilterValue"
        recent-searches-storage-key="recent-metrics-filter-search"
        namespace="metrics-list-filtered-search"
        :tokens="tokens"
        :search-input-placeholder="$options.i18n.searchInputPlaceholder"
        terms-as-tokens
        @on-filter="onFilter"
      />
    </div>

    <gl-loading-icon v-if="loading" size="lg" class="gl-py-5" />

    <gl-infinite-scroll v-else :fetched-items="metrics.length" :max-list-height="listHeight">
      <template #items>
        <observability-no-data-empty-state v-if="!metrics.length" />
        <metrics-table v-else :metrics="metrics" @metric-clicked="onMetricClicked" />
      </template>
      <template #default>
        <span data-testid="metrics-infinite-scrolling-legend"></span>
      </template>
    </gl-infinite-scroll>
  </div>
</template>
