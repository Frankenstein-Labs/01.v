<script>
import { GlBadge, GlIcon, GlTooltipDirective } from '@gitlab/ui';
import { s__ } from '~/locale';

export default {
  components: {
    GlIcon,
    GlBadge,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  i18n: {
    tooltip: s__('Vulnerability|Use AI to understand a vulnerability and suggest a fix'),
  },
};
</script>

<template>
  <gl-badge v-gl-tooltip :title="$options.i18n.tooltip" variant="info">
    <gl-icon name="tanuki-ai" />
    <span data-testid="ai-resolution-badge-text" class="gl-sr-only">{{
      $options.i18n.tooltip
    }}</span>
  </gl-badge>
</template>
