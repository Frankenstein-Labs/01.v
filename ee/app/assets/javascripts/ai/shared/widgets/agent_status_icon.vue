<script>
import { GlIcon } from '@gitlab/ui';
import { getAgentStatusIcon } from 'ee/ai/duo_agents_platform/utils';

export default {
  name: 'AgentStatusIcon',
  components: {
    GlIcon,
  },
  props: {
    status: {
      required: true,
      type: String,
    },
    humanStatus: {
      required: true,
      type: String,
    },
  },
  computed: {
    itemStatus() {
      return getAgentStatusIcon(this.status);
    },
    borderStyle() {
      switch (this.itemStatus.color) {
        case 'green':
          return 'gl-border-green-100 dark:gl-border-green-700 gl-bg-status-success';
        case 'red':
          return 'gl-border-red-100 dark:gl-border-red-700 gl-bg-status-danger';
        case 'blue':
          return 'gl-border-blue-100 dark:gl-border-blue-700 gl-bg-status-info';
        case 'orange':
          return 'gl-border-orange-100 dark:gl-border-orange-700 gl-bg-status-warning';
        case 'neutral':
          return 'gl-border-neutral-100 dark:gl-border-neutral-100 gl-bg-status-neutral';
        default:
          return 'gl-border-neutral-100 dark:gl-border-neutral-700 gl-bg-status-neutral';
      }
    },
    iconStyle() {
      switch (this.itemStatus.color) {
        case 'green':
          return 'gl-bg-green-500';
        case 'red':
          return 'gl-bg-red-500';
        case 'blue':
          return 'gl-bg-blue-500';
        case 'orange':
          return 'gl-bg-orange-500';
        case 'neutral':
          return 'gl-bg-neutral-500';
        default:
          return 'gl-bg-neutral-500';
      }
    },
  },
};
</script>

<template>
  <span
    class="gl-inline-flex gl-h-6 gl-w-6 gl-items-center gl-justify-center gl-rounded-full gl-border-4 gl-border-solid"
    :class="borderStyle"
  >
    <gl-icon
      :name="itemStatus.icon"
      :aria-label="humanStatus"
      class="gl-rounded-full !gl-fill-neutral-0 gl-p-1"
      :class="iconStyle"
    />
  </span>
</template>
