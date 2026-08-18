<script>
import { GlLoadingIcon } from '@gitlab/ui';
import CeCompactCodeDropdown from '~/repository/components/code_dropdown/compact_code_dropdown.vue';
import WorkspacesDropdownGroup from 'ee/workspaces/dropdown_group/components/workspaces_dropdown_group.vue';
import GetProjectDetailsQuery from 'ee/workspaces/common/components/get_project_details_query.vue';
import glLicensedFeaturesMixin from '~/vue_shared/mixins/gl_licensed_features_mixin';

export default {
  name: 'CompactCodeDropdown',
  components: {
    GetProjectDetailsQuery,
    WorkspacesDropdownGroup,
    CeCompactCodeDropdown,
    GlLoadingIcon,
  },
  mixins: [glLicensedFeaturesMixin()],
  inject: ['newWorkspacePath'],
  props: {
    ...CeCompactCodeDropdown.props,
    projectPath: {
      type: String,
      required: true,
    },
    projectId: {
      type: String,
      required: true,
    },
    gitRef: {
      type: String,
      required: false,
      default: '',
    },
  },
  data() {
    return {
      projectDetailsLoaded: false,
      supportsWorkspaces: false,
    };
  },
  computed: {
    isWorkspacesDropdownGroupAvailable() {
      return this.glLicensedFeatures.remoteDevelopment;
    },
    projectIdAsInt() {
      return parseInt(this.projectId, 10);
    },
  },
  methods: {
    onProjectDetailsResult({ clusterAgents }) {
      this.projectDetailsLoaded = true;
      this.supportsWorkspaces = clusterAgents.length > 0;
    },
    onProjectDetailsError() {
      this.projectDetailsLoaded = true;
    },
  },
};
</script>

<template>
  <ce-compact-code-dropdown
    class="git-clone-holder js-git-clone-holder"
    :ssh-url="sshUrl"
    :http-url="httpUrl"
    :kerberos-url="kerberosUrl"
    :xcode-url="xcodeUrl"
    :web-ide-url="webIdeUrl"
    :gitpod-url="gitpodUrl"
    :current-path="currentPath"
    :directory-download-links="directoryDownloadLinks"
    :show-no-ssh-key-message="showNoSshKeyMessage"
    :user-settings-ssh-keys-path="userSettingsSshKeysPath"
    :project-path="projectPath"
    :show-web-ide-button="showWebIdeButton"
    :is-gitpod-enabled-for-user="isGitpodEnabledForUser"
    :is-gitpod-enabled-for-instance="isGitpodEnabledForInstance"
  >
    <template #gl-ee-compact-code-dropdown>
      <div v-if="isWorkspacesDropdownGroupAvailable" class="gl-w-full">
        <get-project-details-query
          :project-full-path="projectPath"
          @result="onProjectDetailsResult"
          @error="onProjectDetailsError"
        />
        <workspaces-dropdown-group
          v-if="projectDetailsLoaded"
          class="gl-w-full"
          :new-workspace-path="newWorkspacePath"
          :project-id="projectIdAsInt"
          :project-full-path="projectPath"
          :supports-workspaces="supportsWorkspaces"
          :git-ref="gitRef"
          border-position="top"
        />
        <div v-else class="gl-my-3 gl-w-full gl-text-center">
          <gl-loading-icon />
        </div>
      </div>
    </template>
  </ce-compact-code-dropdown>
</template>
