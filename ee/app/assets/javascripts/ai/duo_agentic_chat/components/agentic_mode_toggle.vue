<script>
import { GlToggle } from '@gitlab/ui';

export default {
  name: 'AgenticModeToggle',
  components: {
    GlToggle,
  },
  model: {
    prop: 'value',
    event: 'change',
  },
  props: {
    value: {
      type: Boolean,
      required: true,
    },
    disabled: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  emits: ['change'],
};
</script>

<template>
  <gl-toggle
    :value="value"
    :disabled="disabled"
    label-position="left"
    class="gl-h-5"
    @change="$emit('change', $event)"
  >
    <template #label>
      <span class="gl-font-normal gl-text-subtle">{{ s__('DuoChat|Agentic') }}</span>
    </template>
  </gl-toggle>
</template>
