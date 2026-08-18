<script>
import { GlIcon, GlPopover } from '@gitlab/ui';

export default {
  name: 'WorkItemWeightConflictWarning',
  components: {
    GlIcon,
    GlPopover,
  },
  props: {
    weight: {
      type: Number,
      required: false,
      default: null,
    },
    rolledUpWeight: {
      type: Number,
      required: false,
      default: null,
    },
  },
  computed: {
    hasConflictingWeights() {
      return (
        this.weight !== null && this.rolledUpWeight !== null && this.weight !== this.rolledUpWeight
      );
    },
  },
};
</script>

<template>
  <span v-if="hasConflictingWeights">
    <gl-icon
      id="conflicting-weight-warning-icon"
      name="warning"
      class="gl-ml-2 gl-cursor-help"
      variant="warning"
      :aria-label="__('Weight conflict warning')"
    />
    <gl-popover target="conflicting-weight-warning-icon" triggers="hover focus">
      <div class="gl-text-strong">
        {{ __('Assigned weight does not match total of its child items.') }}
      </div>
      <div class="gl-mt-3 gl-flex">
        <span class="gl-flex-grow">
          <div class="gl-text-subtle">{{ __('Assigned weight') }}</div>
          <span class="gl-text-strong">{{ weight }}</span>
        </span>
        <span class="gl-flex-grow">
          <div class="gl-text-subtle">{{ __('Total of child items') }}</div>
          <span class="gl-text-strong">{{ rolledUpWeight }}</span>
        </span>
      </div>
    </gl-popover>
  </span>
</template>
