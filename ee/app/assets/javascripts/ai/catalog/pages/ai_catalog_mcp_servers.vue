<script>
import { fetchPolicies } from '~/lib/graphql';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import AiCatalogListHeader from '../components/ai_catalog_list_header.vue';
import AiCatalogMcpServerList from '../components/ai_catalog_mcp_server_list.vue';
import aiCatalogMcpServersQuery from '../graphql/queries/ai_catalog_mcp_servers.query.graphql';
import { PAGE_SIZE } from '../constants';
import { paginationMethodsFor } from '../pagination_utils';

export default {
  name: 'AiCatalogMcpServers',
  components: {
    AiCatalogListHeader,
    AiCatalogMcpServerList,
  },
  apollo: {
    aiCatalogMcpServers: {
      query: aiCatalogMcpServersQuery,
      variables() {
        return {
          before: null,
          after: null,
          first: PAGE_SIZE,
          last: null,
        };
      },
      fetchPolicy: fetchPolicies.CACHE_AND_NETWORK,
      update: (data) => data?.aiCatalogMcpServers?.nodes || [],
      result({ data }) {
        this.pageInfo = data?.aiCatalogMcpServers?.pageInfo || {};
      },
      error(error) {
        Sentry.captureException(error);
      },
    },
  },
  data() {
    return {
      aiCatalogMcpServers: [],
      pageInfo: {},
    };
  },
  computed: {
    isLoading() {
      return this.$apollo.queries.aiCatalogMcpServers.loading;
    },
  },
  methods: {
    ...paginationMethodsFor('aiCatalogMcpServers'),
  },
};
</script>

<template>
  <div>
    <ai-catalog-list-header :is-experiment="true" />

    <ai-catalog-mcp-server-list
      :is-loading="isLoading"
      :items="aiCatalogMcpServers"
      :page-info="pageInfo"
      :empty-state-title="s__('AICatalog|No MCP servers yet')"
      :empty-state-description="
        s__(
          'AICatalog|Model Context Protocol servers extend agent capabilities with external tools and data sources.',
        )
      "
      @next-page="handleNextPage"
      @prev-page="handlePrevPage"
    />
  </div>
</template>
