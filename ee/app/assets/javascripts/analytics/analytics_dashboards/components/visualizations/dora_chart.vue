<script>
import { GlLoadingIcon } from '@gitlab/ui';
import FilterableComparisonChart from 'ee/analytics/dashboards/components/filterable_comparison_chart.vue';
import GroupOrProjectProvider from 'ee/analytics/dashboards/components/group_or_project_provider.vue';

export default {
  name: 'DoraChart',
  components: {
    FilterableComparisonChart,
    GlLoadingIcon,
    GroupOrProjectProvider,
  },
  props: {
    data: {
      type: Object,
      required: true,
    },
    // Part of the visualizations API, but left unused for dora chart.
    // eslint-disable-next-line vue/no-unused-properties -- options prop is part of the standard visualizations API interface, required for consistency across all visualization components
    options: {
      type: Object,
      required: false,
      default: () => ({}),
    },
  },
  emits: ['set-alerts'],
  computed: {
    filters() {
      const { filters: { labels = [], excludeMetrics = [] } = {} } = this.data;
      return {
        labels,
        excludeMetrics,
      };
    },
  },
  methods: {
    webUrl(group, project, isProject) {
      return isProject ? project.webUrl : group.webUrl;
    },
  },
};
</script>

<template>
  <group-or-project-provider
    #default="{ isProject, isNamespaceLoading, group, project }"
    :full-path="data.namespace"
  >
    <div v-if="isNamespaceLoading" class="gl-flex gl-h-full gl-items-center gl-justify-center">
      <gl-loading-icon size="lg" />
    </div>
    <filterable-comparison-chart
      v-else
      :namespace="data.namespace"
      :filters="filters"
      :is-project="isProject"
      :is-loading="isNamespaceLoading"
      :web-url="webUrl(group, project, isProject)"
      @set-alerts="$emit('set-alerts', $event)"
    />
  </group-or-project-provider>
</template>
