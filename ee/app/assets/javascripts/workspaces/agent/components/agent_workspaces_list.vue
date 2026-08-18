<script>
import { logError } from '~/lib/logger';
import {
  I18N_LOADING_WORKSPACES_FAILED,
  WORKSPACES_LIST_PAGE_SIZE,
  WORKSPACES_LIST_POLL_INTERVAL,
} from '../constants';
import agentWorkspacesListQuery from '../graphql/queries/agent_workspaces_list.query.graphql';
import {
  fetchProjectsDetails,
  populateWorkspacesWithProjectDetails,
} from '../../common/services/utils';
import WorkspacesList from '../../common/components/workspaces_list/workspaces_list.vue';

export const i18n = {
  loadingWorkspacesFailed: I18N_LOADING_WORKSPACES_FAILED,
};

export default {
  name: 'AgentWorkspacesList',
  components: {
    WorkspacesList,
  },
  props: {
    agentName: {
      type: String,
      required: true,
    },
    projectPath: {
      type: String,
      required: true,
    },
  },
  apollo: {
    workspaces: {
      query: agentWorkspacesListQuery,
      pollInterval: WORKSPACES_LIST_POLL_INTERVAL,
      variables() {
        return {
          agentName: this.agentName,
          projectPath: this.projectPath,
          ...this.paginationVariables,
        };
      },
      update(data) {
        return data.project?.clusterAgent?.workspaces?.nodes || [];
      },
      error(err) {
        logError(err);
      },
      async result({ data, error }) {
        if (error) {
          this.error = i18n.loadingWorkspacesFailed;
          return;
        }
        const workspaces = data?.project?.clusterAgent?.workspaces?.nodes;
        const result = await fetchProjectsDetails(this.$apollo, workspaces);

        if (result.error) {
          this.error = i18n.loadingWorkspacesFailed;
          this.workspaces = [];
          logError(result.error);
          return;
        }

        this.workspaces = populateWorkspacesWithProjectDetails(workspaces, result.projects);
        this.pageInfo = data?.project?.clusterAgent?.workspaces?.pageInfo;
      },
    },
  },
  data() {
    return {
      workspaces: [],
      pageInfo: {
        hasNextPage: false,
        hasPreviousPage: false,
        startCursor: null,
        endCursor: null,
      },
      paginationVariables: {
        first: WORKSPACES_LIST_PAGE_SIZE,
        after: null,
        before: null,
      },
      error: '',
    };
  },
  computed: {
    isLoading() {
      return this.$apollo.loading;
    },
  },
  methods: {
    onError(error) {
      this.error = error;
    },
    onPaginationInput(paginationVariables) {
      this.paginationVariables = paginationVariables;
    },
  },
  i18n,
  WORKSPACES_LIST_PAGE_SIZE,
};
</script>
<template>
  <workspaces-list
    :workspaces="workspaces"
    :error="error"
    :page-info="pageInfo"
    :page-size="$options.WORKSPACES_LIST_PAGE_SIZE"
    :is-loading="isLoading"
    @error="onError"
    @page="onPaginationInput"
  />
</template>
