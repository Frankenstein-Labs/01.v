<script>
import { GlBadge, GlIcon, GlAnimatedLoaderIcon, GlTooltipDirective } from '@gitlab/ui';
import { WORKFLOW_NAMES, AI_WORKFLOW_I18N } from './vulnerability_report/constants';

export default {
  name: 'AiInProgressBadge',
  components: {
    GlAnimatedLoaderIcon,
    GlBadge,
    GlIcon,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  AI_WORKFLOW_I18N,
  props: {
    workflowName: {
      type: String,
      required: false,
      default: WORKFLOW_NAMES.RESOLVE_SAST_VULNERABILITY,
      validator: (value) => Object.values(WORKFLOW_NAMES).includes(value),
    },
  },
};
</script>

<template>
  <gl-badge
    v-gl-tooltip
    :title="$options.AI_WORKFLOW_I18N[workflowName].tooltipText"
    variant="info"
    size="sm"
    data-testid="ai-fix-in-progress-badge"
  >
    <gl-icon name="tanuki-ai" class="gl-mr-1" />
    <span data-testid="ai-fix-in-progress-badge-text">
      {{ $options.AI_WORKFLOW_I18N[workflowName].badgeText }}
    </span>
    <span data-testid="ai-fix-in-progress-badge-tooltip" class="gl-sr-only">
      {{ $options.AI_WORKFLOW_I18N[workflowName].tooltipText }}
    </span>
    <gl-animated-loader-icon is-on class="gl-pt-2" />
  </gl-badge>
</template>
