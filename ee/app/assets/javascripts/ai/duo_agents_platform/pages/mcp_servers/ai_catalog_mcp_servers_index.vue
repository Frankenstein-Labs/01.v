<script>
import { s__ } from '~/locale';
import AiCatalogListHeader from 'ee/ai/catalog/components/ai_catalog_list_header.vue';
import AiCatalogMcpServerList from 'ee/ai/catalog/components/ai_catalog_mcp_server_list.vue';
import { MCP_SERVERS_SHOW_ROUTE } from '../../router/constants';

export default {
  name: 'AiCatalogMcpServersIndex',
  components: {
    AiCatalogListHeader,
    AiCatalogMcpServerList,
  },
  props: {
    mcpServers: {
      type: Array,
      required: true,
    },
    pageInfo: {
      type: Object,
      required: true,
    },
    isLoading: {
      type: Boolean,
      required: true,
    },
    description: {
      type: String,
      required: false,
      default: null,
    },
    emptyStateDescription: {
      type: String,
      required: true,
    },
  },
  emits: ['next-page', 'prev-page', 'connect', 'disconnected'],
  MCP_SERVERS_SHOW_ROUTE,
  emptyStateTitle: s__('AICatalog|No MCP servers found'),
};
</script>

<template>
  <div>
    <ai-catalog-list-header :heading="s__('AICatalog|MCP servers')" is-experiment>
      <template v-if="description" #description>
        {{ description }}
      </template>
    </ai-catalog-list-header>

    <ai-catalog-mcp-server-list
      :items="mcpServers"
      :page-info="pageInfo"
      :is-loading="isLoading"
      :empty-state-title="$options.emptyStateTitle"
      :empty-state-description="emptyStateDescription"
      :show-route="$options.MCP_SERVERS_SHOW_ROUTE"
      :show-connect="true"
      @next-page="$emit('next-page')"
      @prev-page="$emit('prev-page')"
      @connect="$emit('connect', $event)"
      @disconnected="$emit('disconnected', $event)"
    />
  </div>
</template>
