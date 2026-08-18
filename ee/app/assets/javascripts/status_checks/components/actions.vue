<script>
import { GlButton, GlTooltipDirective } from '@gitlab/ui';
import { __ } from '~/locale';

export default {
  name: 'StatusChecksActions',
  components: {
    GlButton,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  props: {
    statusCheck: {
      type: Object,
      required: true,
    },
  },
  emits: ['open-delete-modal', 'open-update-modal'],
  i18n: {
    editButton: __('Edit'),
    deleteButton: __('Delete'),
  },
};
</script>

<template>
  <div class="!-gl-my-3 gl-pr-5 gl-text-right">
    <gl-button
      v-gl-tooltip
      category="tertiary"
      icon="pencil"
      :title="$options.i18n.editButton"
      :aria-label="$options.i18n.editButton"
      data-testid="edit-btn"
      @click="$emit('open-update-modal', statusCheck)"
    />
    <gl-button
      v-gl-tooltip
      category="tertiary"
      icon="remove"
      class="gl-ml-2"
      :title="$options.i18n.deleteButton"
      :aria-label="$options.i18n.deleteButton"
      data-testid="delete-btn"
      @click="$emit('open-delete-modal', statusCheck)"
    />
  </div>
</template>
