<script>
import { GlEmptyState, GlLoadingIcon } from '@gitlab/ui';
import emptySearchSvg from '@gitlab/svgs/dist/illustrations/empty-state/empty-search-md.svg';
import { s__ } from '~/locale';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import ErrorsAlert from '~/vue_shared/components/errors_alert.vue';
import { convertToGraphQLId } from '~/graphql_shared/utils';
import { TYPENAME_AI_CATALOG_MCP_SERVER } from '../constants';
import aiCatalogMcpServerQuery from '../graphql/queries/ai_catalog_mcp_server.query.graphql';

export default {
  name: 'AiCatalogMcpServer',
  components: {
    ErrorsAlert,
    GlEmptyState,
    GlLoadingIcon,
  },
  data() {
    return {
      aiCatalogMcpServer: null,
      errors: [],
    };
  },
  apollo: {
    aiCatalogMcpServer: {
      query: aiCatalogMcpServerQuery,
      variables() {
        return {
          id: convertToGraphQLId(TYPENAME_AI_CATALOG_MCP_SERVER, this.$route.params.id),
        };
      },
      update: (data) => data.aiCatalogMcpServer,
      error(error) {
        this.errors = [s__('AICatalog|Failed to load MCP server')];
        Sentry.captureException(error);
      },
    },
  },
  computed: {
    isLoading() {
      return this.$apollo.queries.aiCatalogMcpServer.loading;
    },
    isNotFound() {
      return !this.isLoading && !this.aiCatalogMcpServer;
    },
  },
  watch: {
    aiCatalogMcpServer: {
      handler() {
        if (this.aiCatalogMcpServer?.name) {
          document.title = `${this.aiCatalogMcpServer.name} · ${this.baseTitle}`;
        }
      },
      deep: true,
    },
  },
  created() {
    const itemType = s__('AICatalog|MCP');
    this.baseTitle = document.title.includes(itemType)
      ? document.title
      : `${itemType} · ${document.title}`;
  },
  emptySearchSvg,
};
</script>

<template>
  <div>
    <errors-alert :errors="errors" @dismiss="errors = []" />

    <gl-loading-icon v-if="isLoading" size="lg" class="gl-my-5" />

    <gl-empty-state
      v-else-if="isNotFound"
      :title="s__('AICatalog|MCP server not found.')"
      :svg-path="$options.emptySearchSvg"
    />

    <router-view v-else :ai-catalog-mcp-server="aiCatalogMcpServer" />
  </div>
</template>
