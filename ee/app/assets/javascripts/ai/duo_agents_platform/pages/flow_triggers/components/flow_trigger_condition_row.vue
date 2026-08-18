<script>
import { GlButton, GlIcon, GlTooltipDirective } from '@gitlab/ui';
import { s__ } from '~/locale';
import { FLOW_TRIGGER_MODE_SCHEDULE } from 'ee/ai/duo_agents_platform/constants';
import { flowTriggerEventSummary, flowTriggerModeFor } from 'ee/ai/duo_agents_platform/utils';

export default {
  name: 'FlowTriggerConditionRow',
  components: {
    GlButton,
    GlIcon,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  props: {
    typeValue: {
      type: String,
      required: true,
    },
    filter: {
      type: Object,
      required: false,
      default: () => ({}),
    },
    invalidFeedback: {
      type: String,
      required: false,
      default: null,
    },
    isEditing: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  emits: ['edit', 'remove'],
  computed: {
    isSchedule() {
      return flowTriggerModeFor(this.typeValue) === FLOW_TRIGGER_MODE_SCHEDULE;
    },
    icon() {
      return this.isSchedule ? 'clock' : 'trigger-source';
    },
    summary() {
      return flowTriggerEventSummary(this.typeValue, this.filter);
    },
    editLabel() {
      return this.isSchedule
        ? s__('DuoAgentsPlatform|Edit schedule')
        : s__('DuoAgentsPlatform|Edit event');
    },
    removeLabel() {
      return this.isSchedule
        ? s__('DuoAgentsPlatform|Remove schedule')
        : s__('DuoAgentsPlatform|Remove event');
    },
  },
  i18n: {
    editing: s__('DuoAgentsPlatform|(editing)'),
  },
};
</script>

<template>
  <li
    class="gl-border-b gl-flex gl-items-center gl-justify-between gl-gap-3 gl-border-section gl-px-3 gl-py-3 first:gl-rounded-t-lg last:gl-rounded-b-lg last:gl-border-b-0"
    :class="{ 'gl-bg-subtle': isEditing }"
  >
    <div class="gl-flex gl-min-w-0 gl-items-center gl-gap-3">
      <gl-icon :name="icon" class="gl-shrink-0 gl-text-subtle" />
      <div class="gl-flex gl-min-w-0 gl-flex-col">
        <span class="gl-flex gl-min-w-0 gl-items-center gl-gap-2">
          <span class="gl-truncate gl-font-semibold" :class="{ 'gl-italic': isEditing }">{{
            summary
          }}</span>
          <span
            v-if="isEditing"
            class="gl-shrink-0 gl-italic gl-text-subtle"
            data-testid="editing-indicator"
            >{{ $options.i18n.editing }}</span
          >
        </span>
        <span
          v-if="invalidFeedback"
          role="alert"
          class="gl-text-sm gl-text-danger"
          data-testid="row-error"
        >
          {{ invalidFeedback }}
        </span>
      </div>
    </div>

    <!-- A disabled button never receives the mouseleave that dismisses its tooltip, so an open
         tooltip would hang around for as long as the form is. Keying on the disabled state
         rebuilds the button instead, and tearing the old one down takes its tooltip with it. -->
    <div class="gl-flex gl-shrink-0 gl-items-center gl-gap-2">
      <gl-button
        :key="`edit-${isEditing}`"
        v-gl-tooltip
        :title="editLabel"
        :aria-label="editLabel"
        icon="pencil"
        category="tertiary"
        size="small"
        :disabled="isEditing"
        data-testid="edit-condition-button"
        @click="$emit('edit')"
      />
      <gl-button
        :key="`remove-${isEditing}`"
        v-gl-tooltip
        :title="removeLabel"
        :aria-label="removeLabel"
        icon="remove"
        category="tertiary"
        size="small"
        :disabled="isEditing"
        data-testid="remove-condition-button"
        @click="$emit('remove')"
      />
    </div>
  </li>
</template>
