<script>
import { GlIcon, GlLink, GlTooltip } from '@gitlab/ui';
import { __ } from '~/locale';

export default {
  name: 'WorkItemDevelopmentFfItem',
  components: {
    GlIcon,
    GlLink,
    GlTooltip,
  },
  props: {
    itemContent: {
      type: Object,
      required: true,
    },
  },
  methods: {
    icon({ active }) {
      return active ? 'feature-flag' : 'feature-flag-disabled';
    },
    iconColor({ active }) {
      return active ? 'gl-text-blue-500' : 'gl-text-subtle';
    },
    flagStatus(flag) {
      return flag.active ? __('Enabled') : __('Disabled');
    },
  },
};
</script>

<template>
  <div ref="flagInfo" class="gl-flex gl-items-center gl-gap-3">
    <gl-icon ref="flagIcon" :name="icon(itemContent)" :class="iconColor(itemContent)" />
    <gl-link
      :href="itemContent.path"
      class="gl-truncate gl-font-semibold gl-text-default hover:gl-text-default hover:gl-underline"
    >
      {{ itemContent.name }}
    </gl-link>
    <span class="gl-inline-block gl-text-subtle">{{ itemContent.reference }}</span>
    <gl-tooltip :target="() => $refs.flagIcon" placement="top">
      <div class="gl-font-bold">{{ __('Feature flag') }}</div>
      <div class="gl-text-subtle">{{ flagStatus(itemContent) }}</div>
    </gl-tooltip>
  </div>
</template>
