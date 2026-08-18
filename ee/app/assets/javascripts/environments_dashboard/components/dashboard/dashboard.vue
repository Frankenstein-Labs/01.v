<script>
import {
  GlButton,
  GlDashboardSkeleton,
  GlEmptyState,
  GlLink,
  GlModal,
  GlModalDirective,
  GlPagination,
  GlSprintf,
} from '@gitlab/ui';
import { isEmpty } from 'lodash-es';
// eslint-disable-next-line no-restricted-imports
import { mapState, mapActions } from 'vuex';
import { scrollTo } from '~/lib/utils/scroll_utils';
import { __, s__ } from '~/locale';
import ProjectSelector from '~/vue_shared/components/project_selector/project_selector.vue';
import IndexLayout from '~/vue_shared/components/index_layout.vue';
import Environment from './environment.vue';
import ProjectHeader from './project_header.vue';

export default {
  name: 'EnvironmentsDashboard',
  addProjectsModalHeader: s__('EnvironmentsDashboard|Add projects'),
  addProjectsModalSubmit: s__('EnvironmentsDashboard|Add projects'),

  dashboardHeader: s__('EnvironmentsDashboard|Environments Dashboard'),

  addProjectsButton: s__('EnvironmentsDashboard|Add projects'),

  emptyDashboardHeader: s__('EnvironmentsDashboard|Add a project to the dashboard'),

  emptyDashboardDocs: s__(
    "EnvironmentsDashboard|The environments dashboard provides a summary of each project's environments' status, including pipeline and alert statuses.",
  ),

  viewDocumentationButton: __('View documentation'),
  informationText: s__(
    'EnvironmentsDashboard|This dashboard displays 3 environments per project, and is linked to the Operations Dashboard. When you add or remove a project from one dashboard, GitLab adds or removes the project from the other. %{linkStart}More information%{linkEnd}',
  ),

  components: {
    IndexLayout,
    Environment,
    GlButton,
    GlDashboardSkeleton,
    GlEmptyState,
    GlLink,
    GlModal,
    GlPagination,
    GlSprintf,
    ProjectHeader,
    ProjectSelector,
  },
  directives: {
    'gl-modal': GlModalDirective,
  },
  modalId: 'add-projects-modal',
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
    environmentsDashboardHelpPath: {
      type: String,
      required: true,
    },
  },
  computed: {
    ...mapState([
      'projects',
      'isLoadingProjects',
      'selectedProjects',
      'projectSearchResults',
      'searchCount',
      'messages',
      'pageInfo',
      'projectsPage',
    ]),
    currentPage: {
      get() {
        return this.projectsPage.pageInfo.page;
      },
      set(newPage) {
        this.paginateDashboard(newPage);
      },
    },
    showDashboard() {
      return this.projects.length || this.isLoadingProjects;
    },
    projectsPerPage() {
      return this.projectsPage.pageInfo.perPage;
    },
    totalProjects() {
      return this.projectsPage.pageInfo.total;
    },
    shouldPaginate() {
      return this.projectsPage.pageInfo.totalPages > 1;
    },
    isSearchingProjects() {
      return this.searchCount > 0;
    },
    okDisabled() {
      return isEmpty(this.selectedProjects);
    },
  },
  watch: {
    currentPage() {
      scrollTo({ top: 0, left: 0 }, this.$el);
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
      'fetchSearchResults',
      'addProjectsToDashboard',
      'fetchProjects',
      'fetchNextPage',
      'setProjectEndpoints',
      'clearSearchResults',
      'toggleSelectedProject',
      'setSearchQuery',
      'removeProject',
      'paginateDashboard',
    ]),
    onModalHidden() {
      this.clearSearchResults();
    },
    onOk() {
      this.addProjectsToDashboard();
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
  <index-layout :heading="$options.dashboardHeader" :page-heading-sr-only="!showDashboard">
    <template v-if="showDashboard" #description>
      <gl-sprintf :message="$options.informationText">
        <template #link="{ content }">
          <gl-link :href="environmentsDashboardHelpPath" target="_blank">
            {{ content }}
          </gl-link>
        </template>
      </gl-sprintf>
    </template>
    <template v-if="showDashboard" #actions>
      <gl-button v-gl-modal="$options.modalId" data-testid="add-projects-button" variant="confirm">
        {{ $options.addProjectsButton }}
      </gl-button>
    </template>

    <template v-if="showDashboard">
      <div v-if="projects.length">
        <div v-for="project in projects" :key="project.id">
          <project-header :project="project" @remove="removeProject" />
          <div class="gl-grid gl-gap-5 @md/panel:gl-grid-cols-3">
            <environment
              v-for="environment in project.environments"
              :key="environment.id"
              :environment="environment"
            />
          </div>
        </div>

        <gl-pagination
          v-if="shouldPaginate"
          v-model="currentPage"
          :per-page="projectsPerPage"
          :total-items="totalProjects"
          align="center"
          class="gl-mt-3 gl-w-full"
        />
      </div>

      <gl-dashboard-skeleton v-else-if="isLoadingProjects" />
    </template>

    <gl-empty-state
      v-else
      :title="$options.emptyDashboardHeader"
      :description="$options.emptyDashboardDocs"
      :svg-path="emptyDashboardSvgPath"
    >
      <template #actions>
        <gl-button
          v-gl-modal="$options.modalId"
          data-testid="add-projects-button"
          variant="confirm"
          class="gl-mx-2"
        >
          {{ $options.addProjectsButton }}
        </gl-button>
        <gl-button :href="emptyDashboardHelpPath" class="gl-mx-2" data-testid="documentation-link">
          {{ $options.viewDocumentationButton }}
        </gl-button>
      </template>
    </gl-empty-state>

    <gl-modal
      :modal-id="$options.modalId"
      :title="$options.addProjectsModalHeader"
      :ok-title="$options.addProjectsModalSubmit"
      :ok-disabled="okDisabled"
      @hidden="onModalHidden"
      @ok="onOk"
    >
      <p>
        <gl-sprintf :message="$options.informationText">
          <template #link="{ content }">
            <gl-link :href="environmentsDashboardHelpPath" target="_blank">
              {{ content }}
            </gl-link>
          </template>
        </gl-sprintf>
      </p>
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
