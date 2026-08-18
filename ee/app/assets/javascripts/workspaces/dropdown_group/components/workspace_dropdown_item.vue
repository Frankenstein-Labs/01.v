<script>
import { GlLink } from '@gitlab/ui';
import Tracking from '~/tracking';
import TimeAgoTooltip from '~/vue_shared/components/time_ago_tooltip.vue';
import { s__ } from '~/locale';
import WorkspaceStateIndicator from '../../common/components/workspace_state_indicator.vue';
import WorkspaceActions from '../../common/components/workspace_actions.vue';
import { calculateDisplayState } from '../../common/services/calculate_display_state';
import { WORKSPACE_STATES } from '../constants';

export default {
  components: {
    GlLink,
    WorkspaceStateIndicator,
    WorkspaceActions,
    TimeAgoTooltip,
  },
  i18n: {
    created: s__('Workspaces|Created'),
  },
  mixins: [Tracking.mixin()],
  props: {
    workspace: {
      type: Object,
      required: true,
    },
  },
  emits: ['update-workspace'],
  computed: {
    displayState() {
      return calculateDisplayState(this.workspace.actualState, this.workspace.desiredState);
    },
    isRunning() {
      return this.displayState === WORKSPACE_STATES.running;
    },
  },
  methods: {
    trackOpenWorkspace() {
      this.track('click_consolidated_edit', { label: 'workspace' });
    },
  },
};
</script>
<template>
  <div class="gl-flex gl-items-start gl-justify-between gl-px-4 gl-py-3">
    <span class="gl-inline-flex gl-flex-col gl-items-start gl-gap-2">
      <!--
      TODO: To improve the accessibility of this component, the link to open the Workspace should always be available instead
      of enabling the link only when the Workspace's state is Running. We can't implement this improvement yet because
      opening a "non running" workspace leads to a 404 page. As a follow-up issue, we will
      implement this UX improvement after delivering https://gitlab.com/gitlab-org/gitlab/-/issues/471852
      -->
      <!-- Ensures that the link is accessible using keyboard -->
      <gl-link
        v-if="isRunning"
        :href="workspace.url"
        class="gl-break-anywhere"
        @keydown.stop
        @click="trackOpenWorkspace"
        >{{ workspace.name }}</gl-link
      >
      <span v-else class="gl-break-anywhere">{{ workspace.name }}</span>
      <div class="gl-flex gl-gap-2">
        <workspace-state-indicator :workspace-display-state="displayState" />
        <div class="gl-text-sm gl-text-subtle">
          {{ $options.i18n.created }}
          <time-ago-tooltip :time="workspace.createdAt" />
        </div>
      </div>
    </span>
    <!-- Ensures that the nested dropdown is navigable using keyboard while preserving
        other disclosure dropdown features like closing when pressing ESC key -->
    <span @keydown.stop>
      <workspace-actions
        :workspace-display-state="displayState"
        @click="$emit('update-workspace', { desiredState: $event })"
      />
    </span>
  </div>
</template>
