<script>
import { GlKeysetPagination } from '@gitlab/ui';
import EMPTY_SVG_URL from '@gitlab/svgs/dist/illustrations/empty-state/empty-ai-catalog-md.svg?url';
import ResourceListsEmptyState from '~/vue_shared/components/resource_lists/empty_state.vue';
import AiCatalogListSkeleton from './ai_catalog_list_skeleton.vue';
import AiCatalogMcpServerListItem from './ai_catalog_mcp_server_list_item.vue';

export default {
  name: 'AiCatalogMcpServerList',
  components: {
    AiCatalogListSkeleton,
    AiCatalogMcpServerListItem,
    GlKeysetPagination,
    ResourceListsEmptyState,
  },
  props: {
    items: {
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
    emptyStateTitle: {
      type: String,
      required: true,
    },
    emptyStateDescription: {
      type: String,
      required: false,
      default: null,
    },
    showRoute: {
      type: String,
      required: false,
      default: null,
    },
    showConnect: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  emits: ['next-page', 'prev-page', 'connect', 'disconnected'],
  EMPTY_SVG_URL,
};
</script>

<template>
  <div>
    <ai-catalog-list-skeleton v-if="isLoading" />

    <template v-else-if="items.length > 0">
      <ul class="content-list">
        <ai-catalog-mcp-server-list-item
          v-for="item in items"
          :key="item.id"
          :item="item"
          :show-route="showRoute"
          :show-connect="showConnect"
          @connect="$emit('connect', $event)"
          @disconnected="$emit('disconnected', $event)"
        />
      </ul>

      <div v-if="pageInfo.hasPreviousPage || pageInfo.hasNextPage" class="gl-mt-5 gl-text-center">
        <gl-keyset-pagination
          v-bind="pageInfo"
          @prev="$emit('prev-page')"
          @next="$emit('next-page')"
        />
      </div>
    </template>

    <resource-lists-empty-state
      v-else
      :svg-path="$options.EMPTY_SVG_URL"
      :title="emptyStateTitle"
      :description="emptyStateDescription"
    />
  </div>
</template>
