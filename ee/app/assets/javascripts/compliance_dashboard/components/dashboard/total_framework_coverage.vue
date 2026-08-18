<script>
import { GlProgressBar } from '@gitlab/ui';

export default {
  name: 'TotalFrameworkCoverage',
  components: {
    GlProgressBar,
  },
  props: {
    summary: {
      type: Object,
      required: true,
    },
  },
  computed: {
    coveragePercent() {
      if (!this.summary.totalProjects) {
        return 0;
      }

      return Math.round((this.summary.coveredCount / this.summary.totalProjects) * 100);
    },
  },
};
</script>
<template>
  <div>
    <p class="gl-heading-1 gl-mb-3" data-testid="total-coverage-percent">
      {{ coveragePercent }}<span class="gl-text-lg gl-text-subtle">%</span>
    </p>
    <gl-progress-bar :value="summary.coveredCount" :max="summary.totalProjects || 1" />
  </div>
</template>
