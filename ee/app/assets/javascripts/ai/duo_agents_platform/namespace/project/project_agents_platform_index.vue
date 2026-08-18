<script>
import { s__ } from '~/locale';
import { createAlert } from '~/alert';
import { fetchPolicies } from '~/lib/graphql';
import getProjectAgentFlows from 'ee/ai/duo_agents_platform/graphql/queries/get_agent_flows.query.graphql';
import DuoAgentsPlatformIndex from 'ee/ai/duo_agents_platform/pages/index/duo_agents_platform_index.vue';
import { DEFAULT_AGENT_PLATFORM_PAGINATION_VARIABLES } from 'ee/ai/duo_agents_platform/constants';

export default {
  name: 'ProjectAgentsPlatformIndex',
  components: { DuoAgentsPlatformIndex },
  inject: ['projectPath'],
  data() {
    return {
      workflows: [],
      workflowsPageInfo: {},
      currentSort: 'UPDATED_DESC',
      hasInitialWorkflows: false,
      paginationVariables: { ...DEFAULT_AGENT_PLATFORM_PAGINATION_VARIABLES },
      filterVariables: {},
    };
  },
  apollo: {
    workflows: {
      query: getProjectAgentFlows,
      fetchPolicy: fetchPolicies.CACHE_AND_NETWORK,
      variables() {
        return {
          projectPath: this.projectPath,
          ...this.paginationVariables,
          type: 'non_foundational_chat_agents',
          sort: this.currentSort,
          ...this.filterVariables,
        };
      },
      context: {
        featureCategory: 'duo_agent_platform',
      },
      update(data) {
        return data?.project?.duoWorkflowWorkflows?.edges?.map((w) => w.node) || [];
      },
      result({ data }) {
        this.workflowsPageInfo = data?.project?.duoWorkflowWorkflows?.pageInfo || {};

        const workflows = data?.project?.duoWorkflowWorkflows?.edges?.map((w) => w.node) || [];
        if (workflows.length > 0) {
          this.hasInitialWorkflows = true;
        }
      },
      error(error) {
        createAlert({
          message: error.message || s__('DuoAgentsPlatform|Failed to fetch workflows'),
          captureError: true,
        });
      },
    },
  },
  computed: {
    isLoadingWorkflows() {
      return this.$apollo.queries.workflows.loading;
    },
  },
  methods: {
    handleQueryVariablesUpdate({ sort, pagination, filters, updatedAfter }) {
      this.currentSort = sort;
      this.paginationVariables = pagination;
      this.filterVariables = {
        ...filters,
        ...(updatedAfter && { updatedAfter }),
      };
    },
  },
};
</script>
<template>
  <duo-agents-platform-index
    :has-initial-workflows="hasInitialWorkflows"
    :initial-sort="currentSort"
    :is-loading-workflows="isLoadingWorkflows"
    :workflows="workflows"
    :workflows-page-info="workflowsPageInfo"
    @query-variables-updated="handleQueryVariablesUpdate"
  />
</template>
