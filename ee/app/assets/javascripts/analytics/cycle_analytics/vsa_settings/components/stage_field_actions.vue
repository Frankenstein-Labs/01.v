<script>
import { GlButton, GlTooltipDirective } from '@gitlab/ui';
import { __, s__, sprintf } from '~/locale';

export default {
  name: 'StageFieldActions',
  components: {
    GlButton,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  props: {
    index: {
      type: Number,
      required: true,
    },
    canRemove: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  emits: ['remove', 'hide'],
  computed: {
    hideActionEvent() {
      return this.canRemove ? 'remove' : 'hide';
    },
    hideActionTooltip() {
      return this.canRemove ? __('Remove') : __('Hide');
    },
    hideActionAriaLabel() {
      return sprintf(s__('CreateValueStreamForm|%{action} stage %{index}'), {
        action: this.hideActionTooltip,
        index: this.index + 1,
      });
    },
    hideActionIcon() {
      return this.canRemove ? 'remove' : 'eye-slash';
    },
    hideActionTestId() {
      return `stage-action-${this.canRemove ? 'remove' : 'hide'}-${this.index}`;
    },
  },
};
</script>
<template>
  <div>
    <gl-button
      v-gl-tooltip
      category="tertiary"
      :title="hideActionTooltip"
      :aria-label="hideActionAriaLabel"
      :data-testid="hideActionTestId"
      :icon="hideActionIcon"
      @click="$emit(hideActionEvent, index)"
    />
  </div>
</template>
