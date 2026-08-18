<script>
import { s__ } from '~/locale';
import { createAlert } from '~/alert';
import { convertToGraphQLId } from '~/graphql_shared/utils';
import { TYPENAME_PROJECT } from '~/graphql_shared/constants';
import { initialPaginationParams, reactivePaginationMethods } from 'ee/ai/catalog/pagination_utils';
import AiCatalogMcpServersIndex from '../../pages/mcp_servers/ai_catalog_mcp_servers_index.vue';
import { deduplicateMcpServers, connectMcpServer } from '../../pages/mcp_servers/utils';
import projectMcpServersQuery from '../../graphql/queries/get_project_mcp_servers.query.graphql';

export default {
  name: 'ProjectMcpServersIndex',
  components: {
    AiCatalogMcpServersIndex,
  },
  inject: ['projectId'],
  apollo: {
    projectMcpServers: {
      query: projectMcpServersQuery,
      variables() {
        return {
          projectId: convertToGraphQLId(TYPENAME_PROJECT, this.projectId),
          ...this.paginationVariables,
        };
      },
      update: deduplicateMcpServers,
      result({ data }) {
        this.pageInfo = data?.aiCatalogConfiguredItems?.pageInfo || {};
      },
      error(error) {
        createAlert({
          message: error.message || s__('AICatalog|Could not fetch MCP servers.'),
          captureError: true,
        });
      },
    },
  },
  description: s__('AICatalog|MCP servers associated with the agents enabled in your project.'),
  emptyStateDescription: s__(
    'AICatalog|MCP servers associated with agents in this project appear here.',
  ),
  data() {
    return {
      projectMcpServers: [],
      pageInfo: {},
      paginationVariables: initialPaginationParams(),
    };
  },
  computed: {
    isLoading() {
      return this.$apollo.queries.projectMcpServers.loading;
    },
  },
  methods: {
    ...reactivePaginationMethods,
    handleConnect: connectMcpServer,
    handleDisconnected() {
      this.$apollo.queries.projectMcpServers.refetch();
    },
  },
};
</script>

<template>
  <ai-catalog-mcp-servers-index
    :mcp-servers="projectMcpServers"
    :page-info="pageInfo"
    :is-loading="isLoading"
    :description="$options.description"
    :empty-state-description="$options.emptyStateDescription"
    @next-page="handleNextPage"
    @prev-page="handlePrevPage"
    @connect="handleConnect"
    @disconnected="handleDisconnected"
  />
</template>
