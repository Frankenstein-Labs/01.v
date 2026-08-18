<script>
import { GlIcon, GlTooltip, GlTruncate } from '@gitlab/ui';
import { getAdaptiveStatusColor } from '~/lib/utils/color_utils';

export default {
  name: 'WorkItemStatusBadge',
  components: {
    GlIcon,
    GlTooltip,
    GlTruncate,
  },
  props: {
    item: {
      type: Object,
      required: true,
      default: () => ({
        name: '',
        iconName: '',
        color: '',
        description: '',
      }),
      validator: (value) => {
        return (
          (typeof value.name === 'string' &&
            typeof value.iconName === 'string' &&
            (value.color === undefined || typeof value.color === 'string') &&
            typeof value.description === 'string') ||
          value.description === null
        );
      },
    },
  },
  computed: {
    colorStyle() {
      return this.item.color ? { color: getAdaptiveStatusColor(this.item.color) } : {};
    },
  },
};
</script>

<template>
  <div
    ref="statusBadge"
    class="work-item-status gl-inline-flex gl-max-w-full gl-items-center gl-rounded-pill gl-bg-strong gl-py-1 gl-pl-2 gl-pr-2-5 gl-text-sm gl-leading-normal gl-text-strong"
    data-testid="work-item-status-badge"
    :aria-label="item.name"
  >
    <gl-icon class="gl-shrink-0" :size="12" :name="item.iconName" :style="colorStyle" />
    <div class="gl-shrink-1 gl-ml-2 gl-min-w-0 gl-overflow-hidden">
      <gl-truncate :text="item.name" :with-tooltip="!item.description" />
    </div>
    <gl-tooltip v-if="item.description" :target="() => $refs.statusBadge">
      <p class="gl-mb-1 gl-font-bold">{{ item.name }}</p>
      {{ item.description }}
    </gl-tooltip>
  </div>
</template>
