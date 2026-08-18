<script>
import { s__ } from '~/locale';
import { createAlert } from '~/alert';
import { convertToGraphQLId } from '~/graphql_shared/utils';
import { TYPENAME_GROUP } from '~/graphql_shared/constants';
import { initialPaginationParams, reactivePaginationMethods } from 'ee/ai/catalog/pagination_utils';
import AiCatalogMcpServersIndex from '../../pages/mcp_servers/ai_catalog_mcp_servers_index.vue';
import { deduplicateMcpServers, connectMcpServer } from '../../pages/mcp_servers/utils';
import namespaceMcpServersQuery from '../../graphql/queries/get_namespace_mcp_servers.query.graphql';

export default {
  name: 'GroupMcpServersIndex',
  components: {
    AiCatalogMcpServersIndex,
  },
  inject: {
    groupId: {
      default: null,
    },
  },
  apollo: {
    namespaceMcpServers: {
      query: namespaceMcpServersQuery,
      skip() {
        return !this.groupId;
      },
      variables() {
        return {
          groupId: convertToGraphQLId(TYPENAME_GROUP, this.groupId),
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
  description: s__('AICatalog|MCP servers associated with the agents enabled in your namespace.'),
  emptyStateDescription: s__(
    'AICatalog|MCP servers associated with agents in this group appear here.',
  ),
  data() {
    return {
      namespaceMcpServers: [],
      pageInfo: {},
      paginationVariables: initialPaginationParams(),
    };
  },
  computed: {
    isLoading() {
      return this.$apollo.queries.namespaceMcpServers.loading;
    },
  },
  methods: {
    ...reactivePaginationMethods,
    handleConnect: connectMcpServer,
    handleDisconnected() {
      this.$apollo.queries.namespaceMcpServers.refetch();
    },
  },
};
</script>

<template>
  <ai-catalog-mcp-servers-index
    :mcp-servers="namespaceMcpServers"
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
