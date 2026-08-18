<script>
import { GlSkeletonLoader } from '@gitlab/ui';

export default {
  name: 'HealthCheckListLoader',
  components: {
    GlSkeletonLoader,
  },
};
</script>

<template>
  <gl-skeleton-loader :width="1248" :height="360">
    <rect x="8" y="0" width="300" height="40" rx="4" />

    <rect x="8" y="56" width="20" height="20" rx="16" />
    <rect x="40" y="58" width="300" height="16" rx="4" />
    <rect x="350" y="58" width="300" height="16" rx="4" />
    <rect x="8" y="94" width="20" height="20" rx="16" />
    <rect x="40" y="96" width="200" height="16" rx="4" />

    <rect x="8" y="140" width="350" height="40" rx="4" />

    <rect x="8" y="196" width="20" height="20" rx="16" />
    <rect x="40" y="198" width="450" height="16" rx="4" />
    <rect x="8" y="234" width="20" height="20" rx="16" />
    <rect x="40" y="236" width="360" height="16" rx="4" />

    <rect x="8" y="280" width="200" height="40" rx="4" />

    <rect x="8" y="336" width="20" height="20" rx="16" />
    <rect x="40" y="338" width="260" height="16" rx="4" />
  </gl-skeleton-loader>
</template>
