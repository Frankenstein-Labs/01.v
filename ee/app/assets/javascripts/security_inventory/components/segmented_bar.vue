<script>
export default {
  props: {
    segments: {
      type: Array,
      required: false,
      default: () => {
        return [];
      },
      validator: (value) => value.every(({ count }) => !Number.isNaN(count)),
    },
  },
  computed: {
    totalCount() {
      return this.segments.reduce((sum, segment) => sum + (segment.count || 0), 0);
    },
  },
};
</script>
<template>
  <div
    class="gl-flex gl-h-3 gl-flex-row gl-overflow-hidden gl-rounded-small"
    style="column-gap: 1px"
  >
    <div v-if="!totalCount" class="gl-w-full gl-bg-neutral-200" data-testid="bar-segment"></div>
    <template v-for="(segment, i) in segments" v-else>
      <div
        v-if="segment.count"
        :key="segment.key || `segment-${i}`"
        :class="segment.class"
        :style="{ width: `${(segment.count / totalCount) * 100}%` }"
        data-testid="bar-segment"
      ></div>
    </template>
  </div>
</template>
