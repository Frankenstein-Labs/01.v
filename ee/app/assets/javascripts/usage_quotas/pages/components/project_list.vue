<script>
import { GlEmptyState, GlLoadingIcon, GlAlert } from '@gitlab/ui';
import EMPTY_STATE_SVG_URL from '@gitlab/svgs/dist/illustrations/empty-state/empty-search-md.svg?url';
import { PROJECT_VIEW_TYPE } from '~/usage_quotas/constants';
import GetProjectPagesDeployments from '~/gitlab_pages/queries/get_project_pages_deployments.graphql';
import GetNamespacePagesDeployments from '../graphql/pages_deployments.query.graphql';
import ProjectView from './project.vue';

export default {
  name: 'PagesProjects',
  components: {
    ProjectView,
    GlEmptyState,
    GlLoadingIcon,
    GlAlert,
  },
  EMPTY_STATE_SVG_URL,
  PROJECT_VIEW_TYPE,
  inject: ['fullPath', 'viewType'],
  props: {
    sort: {
      type: String,
      required: false,
      default: null,
    },
  },
  data() {
    return {
      project: null,
      projects: {},
      resultsPerPage: 15,
      error: null,
    };
  },
  apollo: {
    project: {
      query: GetProjectPagesDeployments,
      skip() {
        return !this.isProjectView;
      },
      variables() {
        return {
          fullPath: this.fullPath,
          first: this.resultsPerPage,
          sort: this.sort,
          active: true,
          versioned: true,
        };
      },
      error(error) {
        this.error = error;
      },
    },
    projects: {
      query: GetNamespacePagesDeployments,
      skip() {
        return this.isProjectView;
      },
      variables() {
        return {
          fullPath: this.fullPath,
          first: this.resultsPerPage,
          sort: this.sort,
          active: true,
          versioned: true,
        };
      },
      update(data) {
        return data.namespace.projects.nodes.filter(
          (project) => project.pagesDeployments.count > 0,
        );
      },
      error(error) {
        this.error = error;
      },
    },
  },
  computed: {
    isProjectView() {
      return this.viewType === this.$options.PROJECT_VIEW_TYPE;
    },
    hasResults() {
      if (this.isProjectView) {
        return this.project.pagesDeployments.nodes?.length;
      }
      return this.projects?.length;
    },
  },
};
</script>

<template>
  <div>
    <gl-loading-icon v-if="$apollo.loading" size="lg" />
    <gl-alert v-else-if="error" variant="danger" :dismissible="false" icon="error">
      {{ s__('Pages|An error occurred trying to load the Pages deployments.') }}
    </gl-alert>
    <gl-empty-state
      v-else-if="!isProjectView && !hasResults"
      :title="__('No projects found')"
      :description="
        s__('Pages|We did not find any projects with parallel Pages deployments in this namespace.')
      "
      :svg-path="$options.EMPTY_STATE_SVG_URL"
    />
    <gl-empty-state
      v-else-if="isProjectView && !hasResults"
      :title="__('No parallel deployments')"
      :description="s__('Pages|There are no active parallel Pages deployments in this project.')"
      :svg-path="$options.EMPTY_STATE_SVG_URL"
    />
    <div v-else class="gl-flex gl-flex-col gl-gap-4">
      <project-view v-if="isProjectView" :project="project" />
      <project-view v-for="node in projects" v-else :key="node.id" :project="node" />
    </div>
  </div>
</template>
