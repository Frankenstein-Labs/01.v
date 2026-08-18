<script>
import { GlButton, GlTooltip } from '@gitlab/ui';

export default {
  name: 'BatchUpdateButton',
  components: {
    GlButton,
    GlTooltip,
  },
  props: {
    tooltipTitle: {
      type: String,
      required: true,
    },
    disabled: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  emits: ['batch-update'],
};
</script>
<template>
  <div ref="batchUpdateButton">
    <gl-button category="secondary" :disabled="disabled" @click="$emit('batch-update')">
      {{ __('Apply to all') }}
    </gl-button>
    <gl-tooltip
      data-testid="model-batch-assignment-tooltip"
      :target="() => $refs.batchUpdateButton"
      :title="tooltipTitle"
    />
  </div>
</template>
