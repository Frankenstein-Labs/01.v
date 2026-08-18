<script>
import { GlBadge, GlTooltipDirective } from '@gitlab/ui';

export default {
  name: 'GeoListItemStatus',
  components: {
    GlBadge,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  props: {
    statusArray: {
      type: Array,
      required: false,
      default: () => [],
    },
  },
};
</script>

<template>
  <div>
    <gl-badge
      v-for="(status, index) in statusArray"
      :key="index"
      v-gl-tooltip.hover.focus
      :title="status.tooltip"
      :icon="status.icon"
      :variant="status.variant"
      class="gl-mx-1 gl-cursor-pointer"
      >{{ status.label }}</gl-badge
    >
  </div>
</template>
