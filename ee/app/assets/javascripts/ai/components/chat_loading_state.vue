<script>
import { GlSkeletonLoader } from '@gitlab/ui';

export default {
  name: 'ChatLoadingState',
  components: {
    GlSkeletonLoader,
  },
};
</script>

<template>
  <div class="gl-flex gl-h-full gl-w-full gl-flex-col gl-p-5">
    <!-- Header lines (2 rectangles at top) -->
    <div class="gl-shrink-0">
      <gl-skeleton-loader :height="30" class="gl-mb-2">
        <rect x="0" y="0" width="200" height="20" rx="4" />
      </gl-skeleton-loader>
      <gl-skeleton-loader :height="30">
        <rect x="0" y="0" width="350" height="20" rx="4" />
      </gl-skeleton-loader>
    </div>

    <!-- Spacer that takes remaining space -->
    <div class="gl-grow"></div>

    <!-- Predefined prompt lines (4 thin rectangles) -->
    <div class="gl-mb-3 gl-flex gl-shrink-0 gl-flex-col gl-gap-2">
      <gl-skeleton-loader :height="30">
        <rect x="0" y="0" width="100%" height="20" rx="4" />
      </gl-skeleton-loader>
      <gl-skeleton-loader :height="30">
        <rect x="0" y="0" width="100%" height="20" rx="4" />
      </gl-skeleton-loader>
      <gl-skeleton-loader :height="30">
        <rect x="0" y="0" width="100%" height="20" rx="4" />
      </gl-skeleton-loader>
      <gl-skeleton-loader :height="30">
        <rect x="0" y="0" width="100%" height="20" rx="4" />
      </gl-skeleton-loader>
    </div>

    <!-- Input box (1 large rectangle at bottom) -->
    <div class="gl-shrink-0">
      <gl-skeleton-loader :height="150">
        <rect x="0" y="0" width="100%" height="130" rx="8" />
      </gl-skeleton-loader>
      <gl-skeleton-loader :height="20">
        <rect x="0" y="0" width="100%" height="15" rx="4" />
      </gl-skeleton-loader>
    </div>
  </div>
</template>
