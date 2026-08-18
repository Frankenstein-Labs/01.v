<script>
import { capitalize } from 'lodash-es';
import { formatAgentFlowName } from 'ee/ai/duo_agents_platform/utils';
import { EventsTracker } from '../../observability/events_tracker';
import { getStatusDotClass } from './utils';

export default {
  name: 'SessionPill',
  props: {
    workflowId: {
      type: Number,
      required: true,
    },
    flowName: {
      type: String,
      required: true,
    },
    status: {
      type: String,
      required: true,
    },
  },
  emits: ['click'],
  computed: {
    humanStatus() {
      return capitalize(this.status);
    },
    label() {
      return formatAgentFlowName(this.flowName, this.workflowId);
    },
    statusDotClass() {
      return getStatusDotClass(this.status);
    },
  },
  methods: {
    handleClick() {
      EventsTracker.trackClickThroughSessionPill({ workflowId: this.workflowId });
      this.$emit('click', this.workflowId);
    },
  },
};
</script>

<template>
  <button
    type="button"
    data-testid="session-pill"
    class="gl-border gl-inline-flex gl-max-w-1/2 gl-items-center gl-gap-2 gl-rounded-full gl-border-default gl-bg-default gl-px-3 gl-py-1 gl-text-sm gl-text-default hover:gl-bg-strong"
    :aria-label="`${label} ${humanStatus}`"
    :title="label"
    @click="handleClick"
  >
    <span
      class="gl-inline-block gl-h-3 gl-w-3 gl-shrink-0 gl-rounded-full"
      :class="statusDotClass"
      data-testid="session-pill-status-dot"
      aria-hidden="true"
    ></span>
    <span class="gl-truncate">{{ label }}</span>
  </button>
</template>
