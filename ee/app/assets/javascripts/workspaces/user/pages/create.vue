<script>
import {
  GlAlert,
  GlButton,
  GlForm,
  GlFormGroup,
  GlFormSelect,
  GlPopover,
  GlTooltipDirective,
  GlLink,
  GlSprintf,
} from '@gitlab/ui';
import { omit } from 'lodash-es';
import { DRAWER_Z_INDEX } from '~/lib/utils/constants';
import { s__, n__, sprintf } from '~/locale';
import { createAlert } from '~/alert';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import HelpIcon from '~/vue_shared/components/help_icon/help_icon.vue';
import { logError } from '~/lib/logger';
import { helpPagePath } from '~/helpers/help_page_helper';
import RefSelector from '~/vue_shared/components/ref/components/ref_selector.vue';
import blobContentQuery from '~/ci/pipeline_editor/graphql/queries/blob_content.query.graphql';
import GetProjectDetailsQuery from '../../common/components/get_project_details_query.vue';
import WorkspaceVariables from '../components/workspace_variables.vue';
import SearchProjectsListbox from '../components/search_projects_listbox.vue';
import devfileValidateMutation from '../graphql/mutations/devfile_validate.mutation.graphql';
import workspaceCreateMutation from '../graphql/mutations/workspace_create.mutation.graphql';
import DevfileListbox from '../components/devfile_listbox.vue';
import DevfileHelpDrawer from '../components/devfile_help_drawer.vue';
import { addWorkspace } from '../services/apollo_cache_mutators';
import {
  DEFAULT_DESIRED_STATE,
  ROUTES,
  PROJECT_VISIBILITY,
  DEFAULT_DEVFILE_OPTION,
} from '../constants';

export const i18n = {
  devfileRefHelp: s__('Workspaces|The source branch, tag, or commit hash of your workspace.'),
  title: s__('Workspaces|New workspace'),
  subtitle: s__('Workspaces|A workspace is a virtual sandbox environment for your code in GitLab.'),
  form: {
    devfileProject: s__('Workspaces|Project'),
    projectReference: s__('Workspaces|Project reference'),
    devfile: s__('Workspaces|Devfile'),
    agentId: s__('Workspaces|Cluster agent'),
  },
  invalidProjectAlert: {
    title: s__("Workspaces|You can't create a workspace for this project"),
    noAgentsContent: s__(
      'Workspaces|No agents available to create workspaces. Please consult %{linkStart}Workspaces documentation%{linkEnd} for troubleshooting.',
    ),
  },
  submitButton: {
    create: s__('Workspaces|Create workspace'),
  },
  cancelButton: s__('Workspaces|Cancel'),
  createWorkspaceFailedMessage: s__('Workspaces|Failed to create workspace'),
  fetchProjectDetailsFailedMessage: s__(
    'Workspaces|Could not retrieve cluster agents for this project',
  ),
};

export const devfileHelpPath = helpPagePath('user/workspace/_index.md#devfile');
export const devfileValidationRulesHelpPath = helpPagePath(
  'user/workspace/_index.md#validation-rules',
  {
    anchor: 'validation-rules',
  },
);

export const workspacesTroubleshootingDocsPath = helpPagePath(
  'user/workspace/workspaces_troubleshooting.html',
);

export default {
  name: 'WorkspacesCreate',
  components: {
    GlAlert,
    GlButton,
    GlForm,
    GlFormGroup,
    GlFormSelect,
    GlPopover,
    GlLink,
    GlSprintf,
    HelpIcon,
    RefSelector,
    SearchProjectsListbox,
    GetProjectDetailsQuery,
    WorkspaceVariables,
    DevfileListbox,
    DevfileHelpDrawer,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  data() {
    return {
      selectedProject: null,
      selectedAgent: null,
      isCreatingWorkspace: false,
      clusterAgents: [],
      clusterAgentsMap: {},
      devfileRef: '',
      projectId: null,
      workspaceVariables: [],
      showWorkspaceVariableValidations: false,
      projectDetailsLoaded: false,
      error: '',
      selectedDevfilePath: null,
      devfileValidateErrors: [],
    };
  },
  computed: {
    emptyAgents() {
      return this.clusterAgents.length === 0;
    },
    displayClusterAgentsAlert() {
      return this.projectDetailsLoaded && this.emptyAgents;
    },
    saveWorkspaceEnabled() {
      return (
        this.selectedProject &&
        this.selectedAgent &&
        this.selectedDevfilePath &&
        this.devfileValidateErrors.length === 0
      );
    },
    selectedProjectFullPath() {
      return this.selectedProject?.fullPath || this.$router.currentRoute.query?.project;
    },
    devfilePath() {
      return this.selectedDevfilePath === DEFAULT_DEVFILE_OPTION ? null : this.selectedDevfilePath;
    },
    projectApiId() {
      if (!this.projectId) {
        return '';
      }
      return String(getIdFromGraphQLId(this.projectId));
    },
    hasDevfileValidateErrors() {
      return this.devfileValidateErrors.length > 0;
    },
    hasExactlyOneDevfileValidateError() {
      return this.devfileValidateErrors.length === 1;
    },
    devfilePopoverErrorMessage() {
      return sprintf(
        n__(
          'Workspaces|Error processing the Devfile.',
          'Workspaces|%{count} errors processing the Devfile.',
          this.devfileValidateErrors.length,
        ),
        {
          count: this.devfileValidateErrors.length,
        },
      );
    },
  },
  watch: {
    emptyAgents(newValue) {
      if (!newValue) {
        this.focusAgentSelectDropdown();
      }
    },
  },
  mounted() {
    this.focusFirstElement();
  },
  methods: {
    onProjectDetailsResult({ fullPath, nameWithNamespace, clusterAgents, id, rootRef }) {
      // This scenario happens when the selected project is specified in the URL as a query param
      if (!this.selectedProject) {
        this.setSelectedProject({ fullPath, nameWithNamespace });
      }

      this.projectDetailsLoaded = true;
      this.projectId = id;
      this.devfileRef = this.$router.currentRoute.query?.gitRef || rootRef;
      this.clusterAgents = clusterAgents;

      clusterAgents.forEach((agent) => {
        this.clusterAgentsMap[agent.value] = agent;
      });

      // Select the first agent if there are any
      if (clusterAgents.length > 0) {
        this.selectedAgent = clusterAgents[0].value;
      }
    },
    onProjectDetailsError() {
      createAlert({ message: i18n.fetchProjectDetailsFailedMessage });
      this.resetProjectDetails();
    },
    onSelectProjectFromListbox(selectedProject) {
      this.setSelectedProject(selectedProject);
      this.resetProjectDetails();
    },
    setSelectedProject(selectedProject) {
      this.selectedProject = selectedProject;
    },
    resetProjectDetails() {
      this.clusterAgents = [];
      this.clusterAgentsMap = {};
      this.selectedAgent = null;
      this.projectDetailsLoaded = false;
    },
    validateWorkspaceVariables() {
      this.showWorkspaceVariableValidations = true;
      return this.workspaceVariables.every((variable) => {
        return variable.valid === true;
      });
    },
    async onDevfileSelected(path) {
      this.devfileValidateErrors = [];
      if (path === null || path === DEFAULT_DEVFILE_OPTION) {
        return;
      }
      try {
        const yaml = await this.fetchBlobContent(
          this.selectedProjectFullPath,
          path,
          this.devfileRef,
        );
        if (yaml === null) {
          this.devfileValidateErrors = [s__("Workspaces|Devfile can't be empty.")];
          return;
        }
        const result = await this.$apollo.mutate({
          mutation: devfileValidateMutation,
          variables: {
            input: {
              devfileYaml: yaml,
            },
          },
        });
        this.devfileValidateErrors = result.data.devfileValidate.errors;
      } catch (error) {
        logError(error);
        this.error = s__('Workspaces|Encountered error while attempting to validate the Devfile.');
      }
    },
    async fetchBlobContent(projectPath, devfilePath, devfileRef) {
      const { data } = await this.$apollo.query({
        query: blobContentQuery,
        variables: {
          projectPath,
          path: devfilePath,
          ref: devfileRef,
        },
      });
      return data?.project?.repository?.blobs?.nodes?.[0]?.rawBlob || null;
    },
    async createWorkspace() {
      if (!this.validateWorkspaceVariables()) {
        return;
      }
      try {
        this.isCreatingWorkspace = true;

        // noinspection JSCheckFunctionSignatures - TODO: Address in https://gitlab.com/gitlab-org/gitlab/-/issues/437600
        const result = await this.$apollo.mutate({
          mutation: workspaceCreateMutation,
          variables: {
            input: {
              projectId: this.projectId,
              clusterAgentId: this.selectedAgent,
              desiredState: DEFAULT_DESIRED_STATE,
              devfileRef: this.devfileRef,
              devfilePath: this.devfilePath,
              variables: this.workspaceVariables.map((v) => omit(v, 'valid')),
            },
          },
          update(store, { data }) {
            if (data.workspaceCreate.errors.length > 0) {
              return;
            }

            addWorkspace(store, data.workspaceCreate.workspace);
          },
        });

        const {
          errors: [error],
        } = result.data.workspaceCreate;

        if (error) {
          this.error = error;
          return;
        }

        // noinspection ES6MissingAwait - TODO: Address in https://gitlab.com/gitlab-org/gitlab/-/issues/437600
        this.$router.push(ROUTES.index);
      } catch (error) {
        logError(error);
        this.error = i18n.createWorkspaceFailedMessage;
      } finally {
        this.isCreatingWorkspace = false;
      }
    },
    focusFirstElement() {
      const formElement = this.$refs.form.$el;

      formElement.elements?.[0]?.focus();
    },
    focusAgentSelectDropdown() {
      this.$nextTick(() => {
        // noinspection JSUnresolvedReference - TODO: Address in https://gitlab.com/gitlab-org/gitlab/-/issues/437600
        this.$refs.agentSelect.$el.focus();
      });
    },
  },
  i18n,
  ROUTES,
  PROJECT_VISIBILITY,
  devfileHelpPath,
  devfileValidationRulesHelpPath,
  workspacesTroubleshootingDocsPath,
  DRAWER_Z_INDEX,
  DEFAULT_DEVFILE_OPTION,
};
</script>
<template>
  <div class="gl-flex gl-flex-row gl-gap-5">
    <div class="gl-basis-1/3">
      <div class="gl-flex gl-items-center">
        <h2 ref="pageTitle" class="page-title gl-text-size-h-display">
          {{ $options.i18n.title }}
        </h2>
      </div>
      <p>
        {{ $options.i18n.subtitle }}
      </p>
    </div>
    <get-project-details-query
      :project-full-path="selectedProjectFullPath"
      @result="onProjectDetailsResult"
      @error="onProjectDetailsError"
    />
    <gl-form ref="form" class="gl-mt-6 gl-basis-2/3" @submit.prevent="createWorkspace">
      <gl-form-group
        :label="$options.i18n.form.devfileProject"
        label-for="workspace-devfile-project-id"
      >
        <search-projects-listbox
          id="workspace-search-projects-listbox"
          :value="selectedProject"
          data-testid="workspace-devfile-project-id-field"
          @input="onSelectProjectFromListbox"
        />
        <gl-alert
          v-if="displayClusterAgentsAlert"
          data-testid="no-agents-alert"
          class="gl-mt-3"
          :title="$options.i18n.invalidProjectAlert.title"
          variant="danger"
          :dismissible="false"
        >
          <gl-sprintf :message="$options.i18n.invalidProjectAlert.noAgentsContent">
            <template #link="{ content }">
              <gl-link
                :href="$options.workspacesTroubleshootingDocsPath"
                data-testid="workspaces-troubleshooting-doc-link"
                target="_blank"
                >{{ content }}
              </gl-link>
            </template>
          </gl-sprintf>
        </gl-alert>
      </gl-form-group>
      <template v-if="!emptyAgents">
        <gl-form-group
          :label="$options.i18n.form.agentId"
          label-for="workspace-cluster-agent-id"
          data-testid="workspace-cluster-agent-form-group"
        >
          <gl-form-select
            id="workspace-cluster-agent-id"
            ref="agentSelect"
            v-model="selectedAgent"
            :options="clusterAgents"
            required
            class="gl-max-w-full"
            autocomplete="off"
            data-testid="workspace-cluster-agent-id-field"
          />
        </gl-form-group>
        <template v-if="selectedAgent">
          <gl-form-group
            data-testid="devfile-ref"
            :label="$options.i18n.form.projectReference"
            :label-description="$options.i18n.devfileRefHelp"
          >
            <div class="gl-flex">
              <ref-selector
                id="workspace-devfile-ref"
                v-model="devfileRef"
                :project-id="projectApiId"
              />
            </div>
          </gl-form-group>
          <gl-form-group class="gl-mb-6" data-testid="devfile">
            <template #label>
              <span id="devfile-selector-label" class="gl-flex gl-items-center gl-gap-3">
                {{ $options.i18n.form.devfile }}
                <help-icon id="devfile-help-popover" />
              </span>
            </template>
            <devfile-listbox
              v-model="selectedDevfilePath"
              :project-path="selectedProject.fullPath"
              :devfile-ref="devfileRef"
              toggle-aria-labelled-by="devfile-selector-label"
              :icon="hasDevfileValidateErrors ? 'warning' : ''"
              :variant="hasDevfileValidateErrors ? 'danger' : 'default'"
              category="secondary"
              @input="onDevfileSelected"
            />
            <devfile-help-drawer v-if="selectedDevfilePath === $options.DEFAULT_DEVFILE_OPTION" />
            <gl-popover
              data-testid="gl-devfile-help-popover"
              triggers="hover focus"
              :title="s__('Workspaces|What is a devfile?')"
              placement="top"
              target="devfile-help-popover"
            >
              <div class="gl-flex gl-flex-col">
                <p>
                  {{
                    s__(
                      'Workspaces|A devfile defines the development environment for a GitLab project. A workspace must have a valid devfile in the Git reference you use.',
                    )
                  }}
                </p>
                <p>
                  {{
                    s__(
                      'Workspaces|If your devfile is not in the root directory of your project, specify a relative path.',
                    )
                  }}
                </p>
              </div>
              <gl-link :href="$options.devfileHelpPath" target="_blank">
                {{ s__('Workspaces|Learn more.') }}
              </gl-link>
            </gl-popover>
            <div v-if="hasDevfileValidateErrors">
              <div class="gl-text-control-error">
                {{ s__('Workspaces|Devfile is invalid.') }}
                <gl-link
                  :href="$options.devfileValidationRulesHelpPath"
                  data-testid="validation-docs"
                  target="_blank"
                >
                  {{ s__('Workspaces|Devfile Validation Rules.') }}
                </gl-link>
              </div>

              <gl-button id="devfile-error-information-link" variant="link">
                {{ s__('Workspaces|More Information.') }}
              </gl-button>

              <gl-popover
                data-testid="gl-error-popover"
                triggers="click blur"
                :title="devfilePopoverErrorMessage"
                placement="bottom"
                target="devfile-error-information-link"
                show-close-button
              >
                <template v-if="hasExactlyOneDevfileValidateError">
                  <p class="gl-mb-2">
                    {{ devfileValidateErrors[0] }}
                  </p>
                </template>
                <template v-else>
                  <ul class="gl-mb-2">
                    <li v-for="err in devfileValidateErrors" :key="err" class="gl-mb-1">
                      {{ err }}
                    </li>
                  </ul>
                </template>
              </gl-popover>
            </div>
          </gl-form-group>
          <workspace-variables
            v-model="workspaceVariables"
            class="!gl-mb-5"
            :show-validations="showWorkspaceVariableValidations"
            @add-variable="showWorkspaceVariableValidations = false"
          />
        </template>
      </template>
      <div class="gl-flex gl-gap-3">
        <gl-button
          class="js-no-auto-disable gl-flex"
          :loading="isCreatingWorkspace"
          :disabled="!saveWorkspaceEnabled"
          type="submit"
          data-testid="create-workspace"
          variant="confirm"
        >
          {{ $options.i18n.submitButton.create }}
        </gl-button>
        <gl-button class="gl-flex" data-testid="cancel-workspace" :to="$options.ROUTES.index">
          {{ $options.i18n.cancelButton }}
        </gl-button>
      </div>
      <gl-alert
        v-if="error"
        data-testid="create-workspace-error-alert"
        class="gl-mt-3"
        variant="danger"
        dismissible
        @dismiss="error = ''"
      >
        {{ error }}
      </gl-alert>
    </gl-form>
  </div>
</template>
