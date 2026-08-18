<script>
import { GlButton } from '@gitlab/ui';

export default {
  name: 'ReviewWorkplanEmptyState',
  components: {
    GlButton,
  },
  emits: ['review-workplan'],
};
</script>

<template>
  <div>
    <h2 class="gl-heading-2 gl-mb-0" data-testid="workplan-header">
      {{ s__('DuoAgenticChat|Workplan found') }}
    </h2>
    <p class="gl-text-subtle" data-testid="workplan-description">
      {{ s__('DuoAgenticChat|A workplan has already been started for this item.') }}
    </p>
    <div>
      <gl-button
        variant="confirm"
        data-testid="review-workplan-button"
        @click="$emit('review-workplan')"
      >
        {{ s__('DuoAgenticChat|Review and confirm') }}
      </gl-button>
    </div>
  </div>
</template>
