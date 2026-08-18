<script>
import { uniq, flatten, uniqBy } from 'lodash-es';
import { GlSkeletonLoader } from '@gitlab/ui';
import { sprintf } from '~/locale';
import filterLabelsQueryBuilder, {
  LABEL_PREFIX,
} from '~/analytics/dashboards/graphql/filter_labels_query_builder';
import { DASHBOARD_LABELS_LOAD_ERROR, METRICS_WITHOUT_LABEL_FILTERING } from '../constants';
import ComparisonChart from './comparison_chart.vue';
import ComparisonChartLabels from './comparison_chart_labels.vue';

export default {
  name: 'FilterableComparisonChart',
  components: {
    ComparisonChart,
    ComparisonChartLabels,
    GlSkeletonLoader,
  },
  props: {
    namespace: {
      type: String,
      required: true,
    },
    webUrl: {
      type: String,
      required: true,
    },
    filters: {
      type: Object,
      required: false,
      default: () => ({}),
    },
    isLoading: {
      type: Boolean,
      required: false,
      default: false,
    },
    isProject: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  emits: ['set-alerts'],
  apollo: {
    filterLabelsResults: {
      query() {
        return filterLabelsQueryBuilder(this.filterLabelsQuery, this.isProject);
      },
      variables() {
        return {
          fullPath: this.namespace,
        };
      },
      skip() {
        return !this.hasFilterLabelsQuery || !this.namespace;
      },
      update(data) {
        const labels = Object.entries(data.namespace || {})
          .filter(([key]) => key.includes(LABEL_PREFIX))
          .map(([, { nodes }]) => nodes);
        return uniqBy(flatten(labels), ({ id }) => id);
      },
      error() {
        this.hasLabelErrors = true;
        const labels = this.filterLabelsQuery.join(', ');
        this.$emit('set-alerts', { errors: [sprintf(DASHBOARD_LABELS_LOAD_ERROR, { labels })] });
      },
    },
  },
  data() {
    return {
      filterLabelsResults: [],
      hasLabelErrors: false,
    };
  },
  computed: {
    loading() {
      return this.isLoading || this.$apollo.queries.filterLabelsResults.loading;
    },
    filterLabelsQuery() {
      return this.filters?.labels;
    },
    hasFilterLabelsQuery() {
      return this.filterLabelsQuery.length;
    },
    hasFilterLabels() {
      return this.filterLabelsResults.length > 0;
    },
    filterLabelNames() {
      return this.filterLabelsResults.map(({ title }) => title);
    },
    excludeMetrics() {
      let metrics = this.filters?.excludeMetrics;
      if (this.hasFilterLabels) {
        metrics = [...metrics, ...METRICS_WITHOUT_LABEL_FILTERING];
      }
      return uniq(metrics);
    },
  },
};
</script>
<template>
  <div v-if="loading">
    <gl-skeleton-loader :lines="1" />
  </div>
  <div v-else>
    <div class="gl-py-2 gl-text-right">
      <comparison-chart-labels
        v-if="filterLabelsResults.length"
        :labels="filterLabelsResults"
        :web-url="webUrl"
      />
    </div>
    <comparison-chart
      v-if="!hasLabelErrors"
      :request-path="namespace"
      :is-project="isProject"
      :exclude-metrics="excludeMetrics"
      :filter-labels="filterLabelNames"
      @set-alerts="$emit('set-alerts', $event)"
    />
  </div>
</template>
