<script>
import { GlLoadingIcon } from '@gitlab/ui';
import { UNSUPPORTED_PROJECT_NAMESPACE_ERROR } from 'ee/analytics/dashboards/constants';
import DoraPerformersScoreChart from 'ee/analytics/dashboards/dora_performers_score/components/dora_performers_score_chart.vue';
import GroupOrProjectProvider from 'ee/analytics/dashboards/components/group_or_project_provider.vue';

export default {
  name: 'DoraPerformersScoreVisualization',
  components: {
    DoraPerformersScoreChart,
    GlLoadingIcon,
    GroupOrProjectProvider,
  },
  props: {
    data: {
      type: Object,
      required: true,
    },
    // Part of the visualizations API, but left unused for dora performers score.
    // eslint-disable-next-line vue/no-unused-properties -- options prop is part of the standard visualizations API interface, required for consistency across all visualization components
    options: {
      type: Object,
      required: false,
      default: () => ({}),
    },
  },
  emits: ['set-alerts'],
  computed: {
    fullPath() {
      return this.data?.namespace;
    },
  },
  methods: {
    handleResolveNamespace({ isProject = false }) {
      if (isProject) {
        this.$emit('set-alerts', {
          errors: [UNSUPPORTED_PROJECT_NAMESPACE_ERROR],
          canRetry: false,
        });
      }
    },
    handleError(error) {
      this.$emit('set-alerts', { errors: [error] });
    },
  },
};
</script>
<template>
  <group-or-project-provider
    #default="{ isNamespaceLoading, isProject }"
    :full-path="fullPath"
    @done="handleResolveNamespace"
    @error="handleError"
  >
    <div v-if="isNamespaceLoading" class="gl-flex gl-h-full gl-items-center gl-justify-center">
      <gl-loading-icon size="lg" />
    </div>
    <dora-performers-score-chart
      v-else-if="!isNamespaceLoading && !isProject"
      :data="data"
      @error="handleError"
    />
  </group-or-project-provider>
</template>
