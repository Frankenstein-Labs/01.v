<script>
import {
  GlBadge,
  GlButton,
  GlIcon,
  GlLoadingIcon,
  GlPopover,
  GlTooltipDirective,
} from '@gitlab/ui';
import { s__ } from '~/locale';

export default {
  name: 'ScaVrBadge',
  components: {
    GlBadge,
    GlButton,
    GlIcon,
    GlLoadingIcon,
    GlPopover,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  props: {
    pendingTrigger: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  emits: ['resolve'],
  i18n: {
    badgeText: s__('SecurityReports|VR available'),
    inProgressText: s__('SecurityReports|Starting remediation'),
    inProgressTooltip: s__(
      'SecurityReports|Creating a merge request to resolve this vulnerability...',
    ),
    popoverTitle: s__('SecurityReports|Patched version available'),
    popoverDescription: s__(
      'SecurityReports|Create a merge request that updates the dependency to a fixed version.',
    ),
    resolveButton: s__('SecurityReports|Resolve vulnerability'),
  },
};
</script>

<template>
  <gl-badge
    v-if="pendingTrigger"
    v-gl-tooltip
    :title="$options.i18n.inProgressTooltip"
    variant="info"
    size="sm"
    data-testid="sca-vr-in-progress-badge"
    @click.stop
  >
    <gl-loading-icon size="sm" inline class="gl-mr-2" />
    <span data-testid="sca-vr-in-progress-badge-text">{{ $options.i18n.inProgressText }}</span>
    <span class="gl-sr-only">{{ $options.i18n.inProgressTooltip }}</span>
  </gl-badge>
  <gl-badge v-else ref="badge" variant="tier" size="sm" data-testid="sca-vr-badge" @click.stop>
    <gl-icon name="tanuki-ai" class="gl-mr-1" />
    {{ $options.i18n.badgeText }}
    <gl-popover :target="() => $refs.badge?.$el" placement="left" show-close-button>
      <template #title>{{ $options.i18n.popoverTitle }}</template>
      <p class="gl-mb-3">{{ $options.i18n.popoverDescription }}</p>
      <gl-button
        variant="confirm"
        size="small"
        data-testid="sca-vr-resolve-button"
        @click.stop="$emit('resolve')"
      >
        {{ $options.i18n.resolveButton }}
      </gl-button>
    </gl-popover>
  </gl-badge>
</template>
