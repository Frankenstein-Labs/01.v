<script>
import { __ } from '~/locale';
import TimeAgoTooltip from '~/vue_shared/components/time_ago_tooltip.vue';
import { WORKSPACE_STATES, WORKSPACE_DESIRED_STATES } from '../../constants';
import WorkspaceStateIndicator from '../workspace_state_indicator.vue';
import UpdateWorkspaceMutation from '../update_workspace_mutation.vue';
import WorkspaceActions from '../workspace_actions.vue';
import OpenWorkspaceButton from '../open_workspace_button.vue';
import { calculateDisplayState } from '../../services/calculate_display_state';

export const i18n = {
  created: __('Created'),
};

export default {
  name: 'WorkspacesTable',
  components: {
    WorkspaceStateIndicator,
    WorkspaceActions,
    UpdateWorkspaceMutation,
    OpenWorkspaceButton,
    TimeAgoTooltip,
  },
  props: {
    workspaces: {
      type: Array,
      required: true,
    },
  },
  emits: ['update-failed', 'update-succeed'],
  methods: {
    getWorkspaceDisplayState(workspace) {
      return calculateDisplayState(workspace.actualState, workspace.desiredState);
    },
  },
  i18n,
  WORKSPACE_STATES,
  WORKSPACE_DESIRED_STATES,
};
</script>
<template>
  <update-workspace-mutation
    @update-failed="$emit('update-failed', $event)"
    @update-succeed="$emit('update-succeed')"
  >
    <template #default="{ update }">
      <ul data-testid="workspaces-list" class="gl-list-none gl-p-0">
        <li v-for="item in workspaces" :key="item.id" class="gl-border-b gl-px-3 gl-py-4">
          <div
            class="gl-flex gl-flex-col gl-items-start gl-justify-between gl-gap-3 @sm/panel:gl-flex-row @sm/panel:gl-items-center"
            :data-testid="item.name"
          >
            <div class="gl-flex gl-flex-col gl-gap-3">
              <div class="gl-flex gl-items-center">
                <workspace-state-indicator
                  class="gl-mb-0 gl-mr-3 gl-w-fit"
                  :workspace-display-state="getWorkspaceDisplayState(item)"
                />
                <span class="item-title" data-testid="workspace-name">
                  <span>{{ item.name }} </span>
                </span>
              </div>
              <div class="gl-pb-1 gl-text-sm gl-text-subtle">
                <span data-testid="workspaces-project-name">
                  {{ item.projectName }}
                </span>
                &middot; {{ $options.i18n.created }}
                <time-ago-tooltip
                  class="gl-font-sm-600 gl-whitespace-nowrap gl-text-subtle"
                  :time="item.createdAt"
                />
              </div>
            </div>
            <div class="gl-flex gl-w-full gl-gap-3 @sm/panel:gl-w-auto">
              <open-workspace-button
                class="gl-w-full @sm/panel:gl-w-auto"
                :workspace-display-state="getWorkspaceDisplayState(item)"
                :workspace-url="item.url"
              />
              <workspace-actions
                :workspace-display-state="getWorkspaceDisplayState(item)"
                :data-testid="`${item.name}-action`"
                @click="update(item.id, { desiredState: $event })"
              />
            </div>
          </div>
        </li>
      </ul>
    </template>
  </update-workspace-mutation>
</template>
