<script>
import { GlBadge, GlIcon, GlTooltipDirective } from '@gitlab/ui';
import { s__ } from '~/locale';

export default {
  name: 'AiFixedBadge',
  components: {
    GlIcon,
    GlBadge,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  i18n: {
    tooltip: s__('Vulnerability|AI has created a merge request to resolve this vulnerability'),
  },
};
</script>

<template>
  <gl-badge v-gl-tooltip :title="$options.i18n.tooltip" variant="info">
    <gl-icon name="tanuki-ai" />
    <span data-testid="ai-fixed-badge-tooltip" class="gl-sr-only">{{ $options.i18n.tooltip }}</span>
  </gl-badge>
</template>
