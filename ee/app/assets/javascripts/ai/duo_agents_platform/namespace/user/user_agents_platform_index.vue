<script>
import { s__ } from '~/locale';
import { createAlert } from '~/alert';
import getUserAgentFlows from 'ee/ai/duo_agents_platform/graphql/queries/get_user_agent_flow.query.graphql';
import DuoAgentsPlatformIndex from 'ee/ai/duo_agents_platform/pages/index/duo_agents_platform_index.vue';
import { DEFAULT_AGENT_PLATFORM_PAGINATION_VARIABLES } from 'ee/ai/duo_agents_platform/constants';

export default {
  name: 'UserAgentsPlatformIndex',
  components: { DuoAgentsPlatformIndex },
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
      query: getUserAgentFlows,
      context: {
        featureCategory: 'duo_agent_platform',
      },
      pollInterval: 10000,
      variables() {
        return {
          ...this.paginationVariables,
          type: 'non_foundational_chat_agents',
          sort: this.currentSort,
          ...this.filterVariables,
        };
      },
      update(data) {
        return data?.duoWorkflowWorkflows?.edges?.map((w) => w.node) || [];
      },
      result({ data }) {
        this.workflowsPageInfo = data?.duoWorkflowWorkflows?.pageInfo || {};

        const workflows = data?.duoWorkflowWorkflows?.edges?.map((w) => w.node) || [];
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
    class="gl-min-w-full"
    @query-variables-updated="handleQueryVariablesUpdate"
  />
</template>
