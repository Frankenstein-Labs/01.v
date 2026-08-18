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
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import { projectAutomateAgentSessionPath } from 'ee/lib/utils/path_helpers/project';
import { WORKFLOW_NAMES } from './vulnerability_report/constants';
import { getLatestWorkflowByName, isWorkflowStatusActive } from './vulnerability_report/utils';

export default {
  name: 'SastVrBadge',
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
    item: {
      type: Object,
      required: true,
    },
    pendingTrigger: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  emits: ['resolve'],
  computed: {
    latestSastWorkflow() {
      return getLatestWorkflowByName(this.item, WORKFLOW_NAMES.RESOLVE_SAST_VULNERABILITY);
    },
    hasActiveWorkflow() {
      return isWorkflowStatusActive(this.latestSastWorkflow?.workflow?.status);
    },
    inProgress() {
      return this.hasActiveWorkflow || this.pendingTrigger;
    },
    sessionUrl() {
      const workflowGid = this.latestSastWorkflow?.workflow?.id;
      const projectFullPath = this.item.project?.fullPath;
      if (!workflowGid || !projectFullPath) return undefined;

      const workflowId = getIdFromGraphQLId(workflowGid);
      if (!workflowId) return undefined;

      return projectAutomateAgentSessionPath(projectFullPath, workflowId.toString());
    },
    showSpinner() {
      return this.pendingTrigger || !this.sessionUrl;
    },
    inProgressTooltip() {
      if (!this.sessionUrl) return this.$options.i18n.loadingTooltip;
      return this.$options.i18n.inProgressTooltip;
    },
    inProgressBadgeText() {
      if (!this.sessionUrl) return this.$options.i18n.loadingBadgeText;
      return this.$options.i18n.viewSessionText;
    },
  },
  i18n: {
    badgeText: s__('SecurityReports|VR available'),
    viewSessionText: s__('SecurityReports|View session'),
    loadingBadgeText: s__('SecurityReports|Starting session'),
    popoverTitle: s__('SecurityReports|Vulnerability Resolution available'),
    popoverDescription: s__(
      'SecurityReports|Use AI to create a merge request with a proposed fix.',
    ),
    resolveButton: s__('SecurityReports|Resolve vulnerability'),
    inProgressTooltip: s__(
      'SecurityReports|Vulnerability resolution is running. Open the agent session for live progress.',
    ),
    loadingTooltip: s__('SecurityReports|Starting Vulnerability Resolution agent session...'),
  },
};
</script>

<template>
  <gl-badge
    v-if="inProgress"
    v-gl-tooltip
    :title="inProgressTooltip"
    :href="sessionUrl"
    :target="sessionUrl ? '_blank' : undefined"
    variant="info"
    size="sm"
    data-testid="sast-vr-in-progress-badge"
    @click.stop
  >
    <gl-loading-icon v-if="showSpinner" size="sm" inline class="gl-mr-2" />
    <gl-icon v-else name="tanuki-ai" class="gl-mr-1" />
    <span data-testid="sast-vr-in-progress-badge-text">{{ inProgressBadgeText }}</span>
    <span class="gl-sr-only">{{ inProgressTooltip }}</span>
  </gl-badge>
  <gl-badge v-else ref="badge" variant="tier" size="sm" data-testid="sast-vr-badge" @click.stop>
    <gl-icon name="tanuki-ai" class="gl-mr-1" />
    {{ $options.i18n.badgeText }}
    <gl-popover :target="() => $refs.badge?.$el" placement="left" show-close-button>
      <template #title>{{ $options.i18n.popoverTitle }}</template>
      <p class="gl-mb-3">{{ $options.i18n.popoverDescription }}</p>
      <gl-button variant="confirm" size="small" @click.stop="$emit('resolve')">
        {{ $options.i18n.resolveButton }}
      </gl-button>
    </gl-popover>
  </gl-badge>
</template>
