<script>
export default {
  name: 'ChartTooltipText',
  props: {
    emptyValueText: {
      type: String,
      required: true,
    },
    tooltipValue: {
      type: Array,
      required: false,
      default: () => [],
    },
  },
};
</script>
<template>
  <div>
    <template v-if="!tooltipValue.length">
      {{ emptyValueText }}
    </template>
    <div v-else class="gl-flex gl-flex-col">
      <div v-for="metric in tooltipValue" :key="metric.title" class="gl-flex gl-justify-between">
        <div class="gl-mr-5">{{ metric.title }}</div>
        <div class="gl-font-bold" data-testid="tooltip-value">{{ metric.value }}</div>
      </div>
    </div>
  </div>
</template>
