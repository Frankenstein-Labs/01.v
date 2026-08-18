<script>
import { GlIcon, GlTooltipDirective, GlTruncate } from '@gitlab/ui';
import {
  STEP_CATEGORY_ICONS,
  STEP_UNKNOWN_ICON,
  STEP_STATE_CLASSES,
  STEP_STATE_LABELS,
  STEP_STATES,
  STEP_MUTED_STATES,
  UNKNOWN_LABEL,
  UNKNOWN_STEP_CLASSES,
} from '../constants';

export default {
  name: 'FlowStep',
  components: {
    GlIcon,
    GlTruncate,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  props: {
    category: {
      type: String,
      required: false,
      default: null,
    },
    state: {
      type: String,
      required: true,
      validator: (value) => typeof value === 'string' && value.length > 0,
    },
    title: {
      type: String,
      required: false,
      default: '',
    },
    subtitle: {
      type: String,
      required: false,
      default: '',
    },
    nodeId: {
      type: String,
      required: false,
      default: '',
    },
  },
  computed: {
    icon() {
      return STEP_CATEGORY_ICONS[this.category] ?? STEP_UNKNOWN_ICON;
    },
    stateClasses() {
      return STEP_STATE_CLASSES[this.state] ?? UNKNOWN_STEP_CLASSES;
    },
    subtitleText() {
      return this.subtitle || '\u00A0';
    },
    stateLabel() {
      return STEP_STATE_LABELS[this.state] ?? UNKNOWN_LABEL;
    },
    pulseClass() {
      return this.state === STEP_STATES.RUNNING ? 'flow-step-border-pulse' : '';
    },
    isMuted() {
      return STEP_MUTED_STATES.includes(this.state);
    },
    titleClass() {
      return this.isMuted ? 'gl-text-disabled' : 'gl-text-default';
    },
    subtitleClass() {
      return this.isMuted ? 'gl-text-disabled' : 'gl-text-subtle';
    },
  },
};
</script>

<template>
  <div class="gl-flex gl-h-13 gl-w-15 gl-shrink-0 gl-flex-col gl-items-center">
    <div
      v-gl-tooltip
      :class="[stateClasses, pulseClass]"
      :title="stateLabel"
      :data-flow-node="nodeId"
      class="gl-flex gl-h-10 gl-w-10 gl-shrink-0 gl-items-center gl-justify-center gl-rounded-2xl gl-border-2 gl-border-solid gl-transition-all hover:-gl-translate-y-px hover:gl-shadow-md"
      data-testid="flow-step-box"
    >
      <gl-icon :name="icon" />
    </div>

    <gl-truncate
      v-if="title"
      :text="title"
      with-tooltip
      :class="titleClass"
      class="gl-mt-1 gl-max-w-full gl-text-center gl-font-monospace gl-text-sm gl-font-bold"
      data-testid="flow-step-title"
    />

    <gl-truncate
      :text="subtitleText"
      position="middle"
      with-tooltip
      :aria-hidden="!subtitle"
      :class="subtitleClass"
      class="gl-mt-px gl-max-w-full gl-text-center gl-font-monospace gl-text-xs"
      data-testid="flow-step-subtitle"
    />
  </div>
</template>
