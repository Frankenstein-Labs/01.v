<script>
import { GlButton, GlButtonGroup } from '@gitlab/ui';
import { __, s__, sprintf } from '~/locale';
import { STAGE_SORT_DIRECTION } from '../constants';

export default {
  i18n: {
    moveDownLabel: __('Move down'),
    moveUpLabel: __('Move up'),
  },
  name: 'StageFieldActions',
  components: {
    GlButton,
    GlButtonGroup,
  },
  props: {
    index: {
      type: Number,
      required: true,
    },
    stageCount: {
      type: Number,
      required: true,
    },
  },
  emits: ['move'],
  computed: {
    lastStageIndex() {
      return this.stageCount - 1;
    },
    isFirstActiveStage() {
      return this.index === 0;
    },
    isLastActiveStage() {
      return this.index === this.lastStageIndex;
    },
    moveDownAriaLabel() {
      return sprintf(s__('CreateValueStreamForm|%{action} stage %{index}'), {
        action: this.$options.i18n.moveDownLabel,
        index: this.index + 1,
      });
    },
    moveUpAriaLabel() {
      return sprintf(s__('CreateValueStreamForm|%{action} stage %{index}'), {
        action: this.$options.i18n.moveUpLabel,
        index: this.index + 1,
      });
    },
  },
  STAGE_SORT_DIRECTION,
};
</script>
<template>
  <div>
    <gl-button-group vertical>
      <gl-button
        size="small"
        :data-testid="`stage-action-move-up-${index}`"
        :disabled="isFirstActiveStage"
        icon="chevron-up"
        :title="$options.i18n.moveUpLabel"
        :aria-label="moveUpAriaLabel"
        @click="$emit('move', { index, direction: $options.STAGE_SORT_DIRECTION.UP })"
      />
      <gl-button
        size="small"
        :data-testid="`stage-action-move-down-${index}`"
        :disabled="isLastActiveStage"
        icon="chevron-down"
        :title="$options.i18n.moveDownLabel"
        :aria-label="moveDownAriaLabel"
        @click="$emit('move', { index, direction: $options.STAGE_SORT_DIRECTION.DOWN })"
      />
    </gl-button-group>
  </div>
</template>
