<script>
import { GlBadge } from '@gitlab/ui';

export default {
  name: 'MultiBadgeSelector',
  components: { GlBadge },
  props: {
    options: {
      type: Array,
      required: true,
    },
    value: {
      type: Array,
      required: false,
      default: () => [],
    },
  },
  emits: ['input'],
  methods: {
    toggle(id) {
      const updated = this.value.includes(id)
        ? this.value.filter((v) => v !== id)
        : [...this.value, id];
      this.$emit('input', updated);
    },
  },
};
</script>

<template>
  <div class="gl-flex gl-flex-wrap gl-gap-2">
    <gl-badge
      v-for="option in options"
      :key="option.id"
      :variant="value.includes(option.id) ? 'info' : 'neutral'"
      class="gl-cursor-pointer"
      @click="toggle(option.id)"
    >
      {{ option.label }}
    </gl-badge>
  </div>
</template>
