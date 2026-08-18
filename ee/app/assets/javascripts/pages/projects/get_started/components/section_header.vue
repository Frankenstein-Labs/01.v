<script>
import { GlButton } from '@gitlab/ui';
import { __ } from '~/locale';

export default {
  name: 'SectionHeader',
  components: {
    GlButton,
  },
  props: {
    section: {
      required: true,
      type: Object,
    },
    isExpanded: {
      required: true,
      type: Boolean,
    },
    sectionIndex: {
      type: Number,
      required: true,
    },
  },
  emits: ['toggle-expand'],
  computed: {
    expandButtonLabel() {
      return this.isExpanded ? __('Collapse') : __('Expand');
    },

    expandButtonIcon() {
      return this.isExpanded ? 'chevron-up' : 'chevron-down';
    },
  },
};
</script>

<template>
  <div class="gl-flex gl-h-6 gl-items-center gl-gap-3">
    <span class="gl-flex-1" data-testid="section-title">
      {{ section.title }}
    </span>
    <gl-button
      size="medium"
      category="tertiary"
      :icon="expandButtonIcon"
      :aria-label="expandButtonLabel"
      :data-testid="`section-header-${sectionIndex}`"
      @click="$emit('toggle-expand')"
    />
  </div>
</template>
