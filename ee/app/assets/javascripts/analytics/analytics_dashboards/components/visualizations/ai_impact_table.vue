<script>
import { GlLoadingIcon } from '@gitlab/ui';
import { VALUE_STREAM_METRIC_METADATA } from '~/analytics/shared/constants';
import { buildMetricLink } from '~/analytics/dashboards/utils';
import GroupOrProjectProvider from 'ee/analytics/dashboards/components/group_or_project_provider.vue';
import MetricTable from 'ee/analytics/dashboards/ai_impact/components/metric_table.vue';

export default {
  name: 'AiImpactTable',
  components: {
    GlLoadingIcon,
    GroupOrProjectProvider,
    MetricTable,
  },
  props: {
    data: {
      type: Object,
      required: true,
    },
  },
  emits: ['set-alerts'],
  computed: {
    includeMetrics() {
      const { filters: { includeMetrics = [] } = {} } = this.data;
      return includeMetrics;
    },
    excludeMetrics() {
      const { filters: { excludeMetrics = [] } = {} } = this.data;
      return excludeMetrics;
    },
  },
  methods: {
    buildMetricLinks(isProject) {
      return Object.fromEntries(
        this.$options.metricIdentifiers.map((identifier) => [
          identifier,
          buildMetricLink({
            identifier,
            isProject,
            namespace: this.data.namespace,
          }),
        ]),
      );
    },
  },
  metricIdentifiers: Object.keys(VALUE_STREAM_METRIC_METADATA),
};
</script>
<template>
  <group-or-project-provider
    #default="{ isProject, isNamespaceLoading }"
    :full-path="data.namespace"
  >
    <div v-if="isNamespaceLoading" class="gl-flex gl-h-full gl-items-center gl-justify-center">
      <gl-loading-icon size="lg" />
    </div>
    <metric-table
      v-else
      :namespace="data.namespace"
      :metric-links="buildMetricLinks(isProject)"
      :include-metrics="includeMetrics"
      :exclude-metrics="excludeMetrics"
      @set-alerts="$emit('set-alerts', $event)"
    />
  </group-or-project-provider>
</template>
