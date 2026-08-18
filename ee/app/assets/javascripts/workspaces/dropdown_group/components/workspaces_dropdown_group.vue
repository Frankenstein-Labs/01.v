<script>
import {
  GlAlert,
  GlButton,
  GlDisclosureDropdownGroup,
  GlLoadingIcon,
  GlSprintf,
  GlLink,
} from '@gitlab/ui';
import { s__, __ } from '~/locale';
import { logError } from '~/lib/logger';
import { helpPagePath } from '~/helpers/help_page_helper';
import { convertToGraphQLId } from '~/graphql_shared/utils';
import { TYPENAME_PROJECT } from '~/graphql_shared/constants';
import { InternalEvents } from '~/tracking';
import userWorkspacesListQuery from '../../common/graphql/queries/user_workspaces_list.query.graphql';
import {
  WORKSPACES_DROPDOWN_GROUP_POLL_INTERVAL,
  WORKSPACES_DROPDOWN_GROUP_PAGE_SIZE,
  WORKSPACE_STATES,
  CLICK_NEW_WORKSPACE_BUTTON_EVENT_NAME,
} from '../constants';
import UpdateWorkspaceMutation from '../../common/components/update_workspace_mutation.vue';
import WorkspaceDropdownItem from './workspace_dropdown_item.vue';

const trackingMixin = InternalEvents.mixin();

export const i18n = {
  workspacesGroupLabel: s__('Workspaces|Your workspaces'),
  newWorkspaceButton: s__('Workspaces|New workspace'),
  noWorkspacesMessage: s__(
    'Workspaces|A workspace is a virtual sandbox environment for your code in GitLab.',
  ),
  loadingWorkspacesFailedMessage: s__('Workspaces|Could not load workspaces'),
  noWorkspacesSupportMessage: __(
    'No agents available to create workspaces. Please consult %{linkStart}Workspaces documentation%{linkEnd} for troubleshooting.',
  ),
};

const workspacesHelpPath = helpPagePath('user/workspace/_index.md');
const workspacesTroubleshootingDocsPath = helpPagePath(
  'user/workspace/workspaces_troubleshooting.html',
);

export default {
  components: {
    GlAlert,
    GlButton,
    GlDisclosureDropdownGroup,
    GlLoadingIcon,
    GlLink,
    GlSprintf,
    WorkspaceDropdownItem,
    UpdateWorkspaceMutation,
  },
  mixins: [trackingMixin],
  props: {
    projectId: {
      type: Number,
      required: true,
    },
    projectFullPath: {
      type: String,
      required: true,
    },
    newWorkspacePath: {
      type: String,
      required: true,
    },
    supportsWorkspaces: {
      type: Boolean,
      required: true,
    },
    borderPosition: {
      type: String,
      required: true,
    },
    gitRef: {
      type: String,
      required: false,
      default: '',
    },
  },
  apollo: {
    workspaces: {
      query: userWorkspacesListQuery,
      pollInterval: WORKSPACES_DROPDOWN_GROUP_POLL_INTERVAL,
      variables() {
        return {
          first: WORKSPACES_DROPDOWN_GROUP_PAGE_SIZE,
          after: null,
          before: null,
          includeActualStates: [
            WORKSPACE_STATES.creationRequested,
            WORKSPACE_STATES.starting,
            WORKSPACE_STATES.running,
            WORKSPACE_STATES.stopping,
            WORKSPACE_STATES.stopped,
            WORKSPACE_STATES.terminating,
            WORKSPACE_STATES.failed,
            WORKSPACE_STATES.error,
            WORKSPACE_STATES.unknown,
          ],
          projectIds: [convertToGraphQLId(TYPENAME_PROJECT, this.projectId)],
        };
      },
      skip() {
        return !this.supportsWorkspaces;
      },
      update(data) {
        this.loadingWorkspacesFailed = false;

        return data.currentUser.workspaces?.nodes || [];
      },
      error(err) {
        this.loadingWorkspacesFailed = true;
        logError(err);
      },
    },
  },
  data() {
    return {
      workspaces: [],
      loadingWorkspacesFailed: false,
      updateWorkspaceErrorMessage: null,
    };
  },
  computed: {
    hasWorkspaces() {
      return this.workspaces.length > 0;
    },
    isLoading() {
      return this.$apollo.queries.workspaces.loading;
    },
    newWorkspacePathWithProjectId() {
      const basePath = `${this.newWorkspacePath}?project=${encodeURIComponent(this.projectFullPath)}`;

      return this.gitRef ? `${basePath}&gitRef=${this.gitRef}` : basePath;
    },
  },
  methods: {
    displayUpdateFailedAlert({ error }) {
      this.updateWorkspaceErrorMessage = error;
    },
    hideUpdateFailedAlert() {
      this.updateWorkspaceErrorMessage = null;
    },
    handleNewWorkspaceClick() {
      this.trackEvent(CLICK_NEW_WORKSPACE_BUTTON_EVENT_NAME, { label: document.body.dataset.page });
    },
  },
  i18n,
  workspacesHelpPath,
  workspacesTroubleshootingDocsPath,
};
</script>
<template>
  <update-workspace-mutation
    @update-succeed="hideUpdateFailedAlert"
    @update-failed="displayUpdateFailedAlert"
  >
    <template #default="{ update }">
      <gl-disclosure-dropdown-group
        bordered
        :border-position="borderPosition"
        class="edit-dropdown-group-width gl-pt-2"
        data-testid="workspaces-dropdown-group"
      >
        <template #group-label>
          {{ $options.i18n.workspacesGroupLabel }}
        </template>
        <gl-loading-icon v-if="isLoading" />
        <template v-else>
          <gl-alert v-if="loadingWorkspacesFailed" variant="danger" :dismissible="false">
            {{ $options.i18n.loadingWorkspacesFailedMessage }}
          </gl-alert>
          <template v-else-if="hasWorkspaces">
            <gl-alert
              v-if="updateWorkspaceErrorMessage"
              data-testid="update-workspace-error-alert"
              variant="danger"
              :dismissible="false"
            >
              {{ updateWorkspaceErrorMessage }}
            </gl-alert>
            <workspace-dropdown-item
              v-for="workspace in workspaces"
              :key="workspace.id"
              :workspace="workspace"
              @update-workspace="update(workspace.id, $event)"
            />
          </template>
          <div v-else class="gl-px-4 gl-text-left gl-text-base" data-testid="no-workspaces-message">
            <p class="gl-mb-0 gl-text-sm gl-text-subtle">
              {{ $options.i18n.noWorkspacesMessage }}
            </p>
            <p v-if="!supportsWorkspaces" class="gl-mb-0 gl-mt-2 gl-text-sm gl-text-subtle">
              <gl-sprintf :message="$options.i18n.noWorkspacesSupportMessage">
                <template #link="{ content }">
                  <gl-link
                    :href="$options.workspacesTroubleshootingDocsPath"
                    data-testid="workspaces-troubleshooting-doc-link"
                    target="_blank"
                    >{{ content }}
                  </gl-link>
                </template>
              </gl-sprintf>
            </p>
          </div>
          <div v-if="supportsWorkspaces" class="gl-flex gl-justify-start gl-px-4 gl-py-3">
            <gl-button
              v-if="supportsWorkspaces"
              :href="newWorkspacePathWithProjectId"
              data-testid="new-workspace-button"
              block
              @click="handleNewWorkspaceClick"
              >{{ $options.i18n.newWorkspaceButton }}</gl-button
            >
          </div>
        </template>
      </gl-disclosure-dropdown-group>
    </template>
  </update-workspace-mutation>
</template>
