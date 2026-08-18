<script>
import { GlBadge, GlIcon, GlTooltipDirective } from '@gitlab/ui';
import { __, sprintf } from '~/locale';
import {
  healthStatusTextMap,
  healthStatusVariantMap,
  healthStatusIconMap,
  healthStatusColorMap,
} from 'ee/sidebar/constants';

export default {
  name: 'IssueHealthStatus',
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  components: {
    GlBadge,
    GlIcon,
  },
  props: {
    healthStatus: {
      type: String,
      required: true,
      validator: (value) => Object.keys(healthStatusTextMap).includes(value),
    },
    displayAsText: {
      type: Boolean,
      required: false,
    },
    textSize: {
      type: String,
      required: false,
      default: 'base',
      validator: (value) => ['base', 'sm'].includes(value),
    },
    disableTooltip: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  computed: {
    statusText() {
      return healthStatusTextMap[this.healthStatus];
    },
    statusClass() {
      return healthStatusVariantMap[this.healthStatus];
    },
    statusIcon() {
      return healthStatusIconMap[this.healthStatus];
    },
    statusColor() {
      return healthStatusColorMap[this.healthStatus];
    },
    textSizeClass() {
      switch (this.textSize) {
        case 'sm':
          return 'gl-text-sm';
        case 'base':
        default:
          return 'gl-text-base';
      }
    },
  },
  methods: {
    createAriaLabel() {
      return sprintf(__(`Health status: %{statusText}`), {
        statusText: this.statusText.toLowerCase(),
      });
    },
  },
};
</script>

<template>
  <button
    v-gl-tooltip="{ disabled: disableTooltip }"
    :title="__('Health status')"
    :class="[
      '!gl-cursor-default gl-border-none gl-bg-transparent gl-p-0',
      displayAsText ? 'gl-relative gl-top-1' : 'gl-rounded-pill',
    ]"
    :aria-label="createAriaLabel()"
  >
    <span
      v-if="displayAsText"
      data-testid="status-text"
      class="gl-inline-flex gl-items-center"
      :class="[statusColor, textSizeClass, !disableTooltip ? 'gl-cursor-help' : undefined]"
      ><gl-icon class="gl-mr-2" :size="16" :name="statusIcon" />{{ statusText }}</span
    >
    <gl-badge v-else class="gl-font-bold" :variant="statusClass">
      {{ statusText }}
    </gl-badge>
  </button>
</template>
