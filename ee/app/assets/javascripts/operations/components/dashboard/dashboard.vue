<script>
import {
  GlDashboardSkeleton,
  GlButton,
  GlEmptyState,
  GlLink,
  GlModal,
  GlModalDirective,
  GlSprintf,
} from '@gitlab/ui';
// eslint-disable-next-line no-restricted-imports
import { mapState, mapActions } from 'vuex';
import { s__ } from '~/locale';
import VueDraggable from '~/lib/utils/vue3compat/draggable_compat.vue';
import ProjectSelector from '~/vue_shared/components/project_selector/project_selector.vue';
import IndexLayout from '~/vue_shared/components/index_layout.vue';
import DashboardProject from './project.vue';

export default {
  name: 'OperationsDashboard',
  title: s__('OperationsDashboard|Operations Dashboard'),
  informationText: s__(
    'OperationsDashboard|The Operations and Environments dashboards share the same list of projects. When you add or remove a project from one, GitLab adds or removes the project from the other. %{linkStart}More information%{linkEnd}',
  ),
  moreInformationButton: s__('OperationsDashboard|More information'),
  addProjectsSubmitButton: s__('OperationsDashboard|Add projects'),
  addProjectsCancelButton: s__('OperationsDashboard|Cancel'),
  addProjectsModalHeader: s__('OperationsDashboard|Add projects'),
  dashboardHeader: s__('OperationsDashboard|Operations Dashboard'),
  emptyStateTitle: s__(`OperationsDashboard|Add a project to the dashboard`),
  emptyStateDescription: s__(
    `OperationsDashboard|The operations dashboard provides a summary of each project's operational health, including pipeline and alert statuses.`,
  ),
  components: {
    IndexLayout,
    DashboardProject,
    GlDashboardSkeleton,
    GlButton,
    GlEmptyState,
    GlLink,
    GlModal,
    GlSprintf,
    ProjectSelector,
    VueDraggable,
  },
  directives: {
    'gl-modal': GlModalDirective,
  },
  props: {
    addPath: {
      type: String,
      required: true,
    },
    listPath: {
      type: String,
      required: true,
    },
    emptyDashboardSvgPath: {
      type: String,
      required: true,
    },
    emptyDashboardHelpPath: {
      type: String,
      required: true,
    },
    operationsDashboardHelpPath: {
      type: String,
      required: true,
    },
  },
  modalId: 'add-projects-modal',
  computed: {
    ...mapState([
      'isLoadingProjects',
      'selectedProjects',
      'projectSearchResults',
      'searchCount',
      'messages',
      'pageInfo',
    ]),
    projects: {
      get() {
        return this.$store.state.projects;
      },
      set(projects) {
        this.setProjects(projects);
      },
    },
    showDashboard() {
      return this.projects.length || this.isLoadingProjects;
    },
    isSearchingProjects() {
      return this.searchCount > 0;
    },
    okDisabled() {
      return Object.keys(this.selectedProjects).length === 0;
    },
    modalActionPrimary() {
      return {
        text: this.$options.addProjectsSubmitButton,
        attributes: {
          disabled: this.okDisabled,
          variant: 'confirm',
        },
      };
    },
    modalActionCancel() {
      return {
        text: this.$options.addProjectsCancelButton,
      };
    },
  },
  created() {
    this.setProjectEndpoints({
      list: this.listPath,
      add: this.addPath,
    });
    this.fetchProjects();
  },
  methods: {
    ...mapActions([
      'fetchNextPage',
      'fetchSearchResults',
      'addProjectsToDashboard',
      'fetchProjects',
      'setProjectEndpoints',
      'clearSearchResults',
      'toggleSelectedProject',
      'setSearchQuery',
      'setProjects',
    ]),
    onCancel() {
      this.clearSearchResults();
    },
    onOk() {
      this.addProjectsToDashboard().then(this.clearSearchResults).catch(this.clearSearchResults);
    },
    searched(query) {
      this.setSearchQuery(query);
      this.fetchSearchResults();
    },
    projectClicked(project) {
      this.toggleSelectedProject(project);
    },
  },
};
</script>

<template>
  <index-layout :heading="$options.title" :page-heading-sr-only="!showDashboard">
    <template v-if="showDashboard" #description>
      <gl-sprintf :message="$options.informationText">
        <template #link="{ content }">
          <gl-link :href="operationsDashboardHelpPath" target="_blank">
            {{ content }}
          </gl-link>
        </template>
      </gl-sprintf>
    </template>
    <template v-if="showDashboard" #actions>
      <gl-button
        v-if="projects.length"
        v-gl-modal="$options.modalId"
        variant="confirm"
        category="primary"
        data-testid="add-projects-button"
      >
        {{ $options.addProjectsSubmitButton }}
      </gl-button>
    </template>

    <template v-if="showDashboard">
      <vue-draggable
        v-if="projects.length"
        v-model="projects"
        item-key="id"
        group="dashboard-projects"
        class="gl-grid gl-items-start gl-gap-5 @md/panel:gl-grid-cols-3"
      >
        <dashboard-project v-for="project in projects" :key="project.id" :project="project" />
      </vue-draggable>

      <gl-dashboard-skeleton v-else-if="isLoadingProjects" />
    </template>

    <gl-empty-state
      v-else
      :title="$options.emptyStateTitle"
      :description="$options.emptyStateDescription"
      :svg-path="emptyDashboardSvgPath"
    >
      <template #actions>
        <gl-button
          v-gl-modal="$options.modalId"
          variant="confirm"
          data-testid="add-projects-button"
          class="gl-mx-2 gl-mb-3"
        >
          {{ $options.addProjectsSubmitButton }}
        </gl-button>
        <gl-button
          :href="emptyDashboardHelpPath"
          data-testid="documentation-link"
          class="gl-mx-2 gl-mb-3"
        >
          {{ $options.moreInformationButton }}
        </gl-button>
      </template>
    </gl-empty-state>

    <gl-modal
      :modal-id="$options.modalId"
      :title="$options.addProjectsModalHeader"
      :action-primary="modalActionPrimary"
      :action-cancel="modalActionCancel"
      data-testid="add-projects-modal"
      @canceled="onCancel"
      @primary="onOk"
    >
      <project-selector
        ref="projectSelector"
        :project-search-results="projectSearchResults"
        :selected-projects="selectedProjects"
        :show-no-results-message="messages.noResults"
        :show-loading-indicator="isSearchingProjects"
        :show-minimum-search-query-message="messages.minimumQuery"
        :show-search-error-message="messages.searchError"
        :total-results="pageInfo.totalResults"
        @searched="searched"
        @project-clicked="projectClicked"
        @bottom-reached="fetchNextPage"
      />
    </gl-modal>
  </index-layout>
</template>
