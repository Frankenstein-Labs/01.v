<script>
import { formatNumber } from '~/locale';

export default {
  name: 'StatsBarItem',
  props: {
    label: {
      type: String,
      required: true,
    },
    value: {
      type: Number,
      required: true,
    },
  },
  computed: {
    formattedValue() {
      return formatNumber(this.value);
    },
  },
};
</script>

<template>
  <div class="gl-flex-1 gl-rounded-lg gl-bg-subtle gl-p-2">
    <p class="gl-mb-2 gl-px-2 gl-pt-1 gl-text-sm gl-font-bold gl-text-secondary">{{ label }}</p>
    <div class="gl-border gl-rounded-base gl-border-default gl-bg-default gl-px-4 gl-py-3">
      <span class="gl-text-size-h-display gl-font-bold">{{ formattedValue }}</span>
    </div>
  </div>
</template>
