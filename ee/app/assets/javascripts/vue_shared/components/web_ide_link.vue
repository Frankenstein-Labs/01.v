<script>
import { GlLoadingIcon } from '@gitlab/ui';
import CeWebIdeLink from '~/vue_shared/components/web_ide_link.vue';
import glLicensedFeaturesMixin from '~/vue_shared/mixins/gl_licensed_features_mixin';
import WorkspacesDropdownGroup from 'ee_component/workspaces/dropdown_group/components/workspaces_dropdown_group.vue';
import GetProjectDetailsQuery from 'ee_component/workspaces/common/components/get_project_details_query.vue';

export default {
  name: 'WebIdeLink',
  components: {
    GlLoadingIcon,
    WorkspacesDropdownGroup,
    GetProjectDetailsQuery,
    CeWebIdeLink,
  },
  mixins: [glLicensedFeaturesMixin()],
  inject: {
    newWorkspacePath: {
      default: '',
    },
  },
  props: {
    ...CeWebIdeLink.props,
    projectPath: {
      type: String,
      required: false,
      default: '',
    },
    projectId: {
      type: Number,
      required: false,
      default: 0,
    },
    gitRef: {
      type: String,
      required: false,
      default: '',
    },
  },
  emits: ['edit'],
  data() {
    return {
      isDropdownVisible: false,
      projectDetailsLoaded: false,
      supportsWorkspaces: false,
    };
  },
  computed: {
    isWorkspacesDropdownGroupAvailable() {
      return this.glLicensedFeatures.remoteDevelopment;
    },
    shouldRenderWorkspacesDropdownGroup() {
      return this.isWorkspacesDropdownGroupAvailable && this.isDropdownVisible;
    },
    shouldRenderWorkspacesDropdownGroupBeforeActions() {
      return this.shouldRenderWorkspacesDropdownGroup && this.supportsWorkspaces;
    },
    shouldRenderWorkspacesDropdownGroupAfterActions() {
      return this.shouldRenderWorkspacesDropdownGroup && !this.supportsWorkspaces;
    },
  },
  methods: {
    onDropdownShown() {
      this.isDropdownVisible = true;
    },
    onDropdownHidden() {
      this.isDropdownVisible = false;
    },
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
  <ce-web-ide-link
    v-bind="$props"
    @edit="$emit('edit', $event)"
    @shown="onDropdownShown"
    @hidden="onDropdownHidden"
  >
    <template v-if="shouldRenderWorkspacesDropdownGroup" #after-actions>
      <get-project-details-query
        :project-full-path="projectPath"
        @result="onProjectDetailsResult"
        @error="onProjectDetailsError"
      />
      <workspaces-dropdown-group
        v-if="projectDetailsLoaded"
        :new-workspace-path="newWorkspacePath"
        :project-id="projectId"
        :project-full-path="projectPath"
        :supports-workspaces="supportsWorkspaces"
        :git-ref="gitRef"
        border-position="top"
      />
      <div v-else class="gl-my-3">
        <gl-loading-icon />
      </div>
    </template>
  </ce-web-ide-link>
</template>
