<script>
import { GlAnimatedChevronRightDownIcon, GlTooltipDirective } from '@gitlab/ui';
import { n__, sprintf } from '~/locale';
import {
  STEP_STATE_DOT_CLASSES,
  STEP_STATE_LABELS,
  STAGE_RUNNING_STATE,
  STATUS_PULSE_CLASS,
  NEUTRAL_BG_CLASS,
  UNKNOWN_LABEL,
} from '../constants';

export default {
  name: 'FlowStage',
  components: {
    GlAnimatedChevronRightDownIcon,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  props: {
    title: {
      type: String,
      required: true,
    },
    state: {
      type: String,
      required: true,
      validator: (value) => typeof value === 'string' && value.length > 0,
    },
    environmentsCount: {
      type: Number,
      required: false,
      default: 0,
    },
    steps: {
      type: Array,
      required: false,
      default: () => [],
    },
    expanded: {
      type: Boolean,
      required: false,
      default: false,
    },
    nodeId: {
      type: String,
      required: false,
      default: '',
    },
  },
  emits: ['toggle'],
  computed: {
    stepStates() {
      return this.steps.map((step) => step.state);
    },
    isRunning() {
      return this.state === STAGE_RUNNING_STATE;
    },
    stateLabel() {
      return this.stepDotLabel(this.state);
    },
    dotClass() {
      return this.stepDotClass(this.state);
    },
    titleClass() {
      return this.isRunning ? 'gl-text-status-info' : 'gl-text-strong';
    },
    borderClass() {
      return this.isRunning ? 'gl-border-feedback-info' : 'gl-border-subtle';
    },
    statusDotPulseClass() {
      return this.isRunning ? STATUS_PULSE_CLASS : '';
    },
    environmentsLabel() {
      return sprintf(
        n__(
          'ContinuousDeployment|%{count} env',
          'ContinuousDeployment|%{count} envs',
          this.environmentsCount,
        ),
        {
          count: this.environmentsCount,
        },
      );
    },
    stepsLabel() {
      return sprintf(
        n__(
          'ContinuousDeployment|%{count} step',
          'ContinuousDeployment|%{count} steps',
          this.stepStates.length,
        ),
        {
          count: this.stepStates.length,
        },
      );
    },
  },
  methods: {
    stepDotClass(state) {
      return STEP_STATE_DOT_CLASSES[state] ?? NEUTRAL_BG_CLASS;
    },
    stepDotLabel(state) {
      return STEP_STATE_LABELS[state] ?? UNKNOWN_LABEL;
    },
    toggle() {
      this.$emit('toggle');
    },
  },
};
</script>

<template>
  <div
    :class="borderClass"
    :data-flow-node="nodeId"
    class="gl-flex gl-min-w-20 gl-shrink-0 gl-flex-col gl-rounded-lg gl-border-1 gl-border-solid gl-bg-overlap gl-px-4 gl-py-3 gl-shadow-md gl-backdrop-blur-md"
  >
    <button
      type="button"
      class="gl-flex gl-min-h-8 gl-cursor-pointer gl-items-center gl-gap-3 gl-border-0 gl-bg-transparent gl-p-0 gl-text-left"
      :aria-expanded="expanded.toString()"
      data-testid="stage-header"
      @click="toggle"
    >
      <gl-animated-chevron-right-down-icon :is-on="expanded" class="gl-shrink-0 gl-text-subtle" />
      <span
        v-gl-tooltip
        :class="[dotClass, statusDotPulseClass]"
        :title="stateLabel"
        class="gl-h-3 gl-w-3 gl-shrink-0 gl-rounded-full"
        data-testid="stage-status-dot"
      ></span>
      <span
        :class="titleClass"
        class="gl-truncate gl-font-monospace gl-text-sm gl-font-bold gl-uppercase gl-tracking-wider"
        data-testid="stage-title"
      >
        {{ title }}
      </span>
      <span v-if="environmentsCount" class="gl-shrink-0 gl-text-xs gl-text-subtle">
        {{ environmentsLabel }}
      </span>
    </button>

    <div v-if="expanded" class="gl-pb-3 gl-pt-3" data-testid="stage-body">
      <slot></slot>
    </div>

    <div v-else class="gl-flex gl-flex-col gl-gap-2 gl-pt-3" data-testid="stage-summary">
      <span class="gl-inline-flex gl-items-center gl-gap-2">
        <span
          v-for="(stepState, index) in stepStates"
          :key="index"
          v-gl-tooltip
          :class="stepDotClass(stepState)"
          :title="stepDotLabel(stepState)"
          class="gl-h-3 gl-w-3 gl-rounded-full"
          data-testid="step-dot"
        ></span>
      </span>
      <span class="gl-text-sm gl-text-subtle" data-testid="step-count">{{ stepsLabel }}</span>
    </div>
  </div>
</template>
