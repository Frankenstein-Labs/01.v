<script>
import { GlSkeletonLoader } from '@gitlab/ui';

export default {
  name: 'SubscriptionSeatDetailsLoader',
  components: {
    GlSkeletonLoader,
  },
  shapes: [
    { type: 'rect', width: '100', height: '10', x: '20', y: '20' },
    { type: 'rect', width: '100', height: '10', x: '385', y: '20' },
    { type: 'rect', width: '100', height: '10', x: '760', y: '20' },
    { type: 'rect', width: '30', height: '10', x: '970', y: '20' },
  ],
  rowsToRender: {
    mobile: 1,
    desktop: 5,
  },
};
</script>

<template>
  <div>
    <div class="gl-flex-col @sm/panel:gl-hidden" data-testid="mobile-loader">
      <gl-skeleton-loader
        v-for="index in $options.rowsToRender.mobile"
        :key="index"
        :width="500"
        :height="170"
        preserve-aspect-ratio="xMinYMax meet"
      >
        <rect width="500" height="10" x="0" y="15" rx="4" />
      </gl-skeleton-loader>
    </div>
    <div class="gl-hidden gl-flex-col @sm/panel:gl-flex" data-testid="desktop-loader">
      <gl-skeleton-loader
        v-for="index in $options.rowsToRender.desktop"
        :key="index"
        :width="1000"
        :height="54"
        preserve-aspect-ratio="xMinYMax meet"
      >
        <component
          :is="r.type"
          v-for="(r, rIndex) in $options.shapes"
          :key="rIndex"
          rx="4"
          v-bind="r"
        />
      </gl-skeleton-loader>
    </div>
  </div>
</template>
