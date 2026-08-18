<script>
import { GlSkeletonLoader } from '@gitlab/ui';

export default {
  name: 'CatalogSkeleton',
  components: { GlSkeletonLoader },
};
</script>

<template>
  <div data-testid="catalog-skeleton">
    <gl-skeleton-loader :width="248" :height="136">
      <rect width="248" height="40" rx="8" ry="8" y="0" />
      <rect width="248" height="40" rx="8" ry="8" y="48" />
      <rect width="248" height="40" rx="8" ry="8" y="96" />
    </gl-skeleton-loader>
  </div>
</template>
