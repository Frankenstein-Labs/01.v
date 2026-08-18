<script>
import {
  GlAlert,
  GlBadge,
  GlButton,
  GlKeysetPagination,
  GlLink,
  GlLoadingIcon,
  GlTable,
  GlTruncate,
  GlTooltipDirective,
} from '@gitlab/ui';
import { isAbsolute } from '~/lib/utils/url_utility';
import { s__ } from '~/locale';
import getMcpServersQuery from '../../graphql/queries/get_mcp_servers.query.graphql';
import setMcpServerBlockMutation from '../../graphql/mutations/set_mcp_server_block.mutation.graphql';

const DEFAULT_PAGE_SIZE = 20;

// AiCatalogMcpServerBlockStatus GraphQL enum values.
const STATUS_ACTIVE = 'ACTIVE';
const STATUS_BLOCKED_BY_ANCESTOR = 'BLOCKED_BY_ANCESTOR';

export default {
  name: 'McpRegistryApp',
  components: {
    GlAlert,
    GlBadge,
    GlButton,
    GlKeysetPagination,
    GlLink,
    GlLoadingIcon,
    GlTable,
    GlTruncate,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  inject: {
    groupFullPath: { default: '' },
    projectFullPath: { default: '' },
  },
  apollo: {
    mcpServers: {
      query: getMcpServersQuery,
      variables() {
        return this.queryVariables;
      },
      update(data) {
        return data.aiCatalogMcpServers;
      },
      result({ data }) {
        if (data) {
          this.hasError = false;
        }
      },
      error() {
        this.hasError = true;
      },
    },
  },
  data() {
    return {
      mcpServers: null,
      after: null,
      before: null,
      hasError: false,
      mutationError: false,
      mutatingId: null,
    };
  },
  computed: {
    isProject() {
      return Boolean(this.projectFullPath);
    },
    // Block status and block/allow are scoped to the most-specific container: a project when on a
    // project page, otherwise the group. Exactly one path is sent; the other is null.
    scopeVariables() {
      return this.isProject
        ? { projectFullPath: this.projectFullPath, groupFullPath: null }
        : { groupFullPath: this.groupFullPath, projectFullPath: null };
    },
    queryVariables() {
      return {
        ...this.scopeVariables,
        last: this.before ? DEFAULT_PAGE_SIZE : null,
        first: this.before ? null : DEFAULT_PAGE_SIZE,
        after: this.after,
        before: this.before,
      };
    },
    isLoading() {
      return this.$apollo.queries.mcpServers.loading;
    },
    items() {
      return this.mcpServers?.nodes || [];
    },
    pageInfo() {
      return this.mcpServers?.pageInfo || {};
    },
  },
  methods: {
    isBlocked(item) {
      return item.blockStatus !== STATUS_ACTIVE;
    },
    isInherited(item) {
      return item.blockStatus === STATUS_BLOCKED_BY_ANCESTOR;
    },
    // The backend already restricts MCP server URLs to http/https (addressable_url validator); this
    // guards the href too so only http(s) links render, stripping any unsafe scheme as defense-in-depth.
    safeUrl(url) {
      return isAbsolute(url) ? url : '';
    },
    async toggleBlock(item) {
      this.mutationError = false;
      this.mutatingId = item.id;

      try {
        const { data } = await this.$apollo.mutate({
          mutation: setMcpServerBlockMutation,
          variables: {
            id: item.id,
            ...this.scopeVariables,
            blocked: !this.isBlocked(item),
          },
        });

        const errors = data?.aiCatalogMcpServerSetBlock?.errors || [];
        if (errors.length) {
          this.mutationError = true;
        }
      } catch {
        this.mutationError = true;
      } finally {
        this.mutatingId = null;
      }
    },
    handleNext(endCursor) {
      this.after = endCursor;
      this.before = null;
    },
    handlePrev(startCursor) {
      this.before = startCursor;
      this.after = null;
    },
  },
  fields: [
    {
      key: 'name',
      label: s__('AiGovernance|MCP server'),
      thClass: 'gl-w-3/12',
    },
    {
      key: 'description',
      label: s__('AiGovernance|Description'),
      thClass: 'gl-w-4/12',
    },
    {
      key: 'url',
      label: s__('AiGovernance|Connection'),
      thClass: 'gl-w-2/12',
    },
    {
      key: 'type',
      label: s__('AiGovernance|Type'),
      thClass: 'gl-w-1/12',
      tdClass: 'gl-whitespace-nowrap',
    },
    {
      key: 'status',
      label: s__('AiGovernance|Status'),
      thClass: 'gl-w-1/12',
      tdClass: 'gl-whitespace-nowrap',
    },
    {
      key: 'actions',
      label: '',
      thClass: 'gl-w-1/12',
      tdClass: 'gl-whitespace-nowrap gl-text-right gl-align-middle',
    },
  ],
  i18n: {
    inheritedTooltip: s__('AiGovernance|Blocked by a parent group and cannot be changed here.'),
    block: s__('AiGovernance|Block'),
    allow: s__('AiGovernance|Allow'),
  },
};
</script>

<template>
  <div class="gl-mt-5">
    <gl-alert v-if="hasError" variant="danger" :dismissible="false" class="gl-mb-5">
      {{ s__('AiGovernance|Failed to load MCP servers.') }}
    </gl-alert>

    <gl-alert
      v-if="mutationError"
      variant="danger"
      class="gl-mb-5"
      data-testid="mcp-mutation-error"
      @dismiss="mutationError = false"
    >
      {{ s__('AiGovernance|Failed to update the MCP server. Try again.') }}
    </gl-alert>

    <gl-table
      :fields="$options.fields"
      :items="items"
      :busy="isLoading"
      show-empty
      stacked="sm"
      class="gl-w-full"
      table-class="gl-table-fixed"
      :tbody-tr-attr="{ 'data-testid': 'mcp-server-row' }"
    >
      <template #table-busy>
        <gl-loading-icon size="lg" class="gl-my-5" />
      </template>

      <template #empty>
        <div class="gl-py-5 gl-text-center" data-testid="mcp-servers-empty">
          {{ s__('AiGovernance|No MCP servers found.') }}
        </div>
      </template>

      <template #cell(name)="{ item }">
        <div class="gl-overflow-hidden">
          <gl-truncate
            :text="item.name"
            class="gl-min-w-0 gl-max-w-full gl-font-bold"
            with-tooltip
            data-testid="mcp-server-name"
          />
        </div>
      </template>

      <template #cell(description)="{ item }">
        <div class="gl-overflow-hidden">
          <gl-truncate
            v-if="item.description"
            :text="item.description"
            class="gl-min-w-0 gl-max-w-full"
            with-tooltip
            data-testid="mcp-server-description"
          />
          <span v-else class="gl-text-subtle">{{ s__('AiGovernance|None') }}</span>
        </div>
      </template>

      <template #cell(url)="{ item }">
        <div class="gl-overflow-hidden">
          <gl-link :href="safeUrl(item.url)" class="gl-font-monospace" data-testid="mcp-server-url">
            <gl-truncate :text="item.url" class="gl-min-w-0 gl-max-w-full" with-tooltip />
          </gl-link>
        </div>
      </template>

      <template #cell(type)>
        <gl-badge variant="warning" data-testid="mcp-server-type">
          {{ s__('AiGovernance|External') }}
        </gl-badge>
      </template>

      <template #cell(status)="{ item }">
        <gl-badge :variant="isBlocked(item) ? 'danger' : 'success'" data-testid="mcp-server-status">
          {{ isBlocked(item) ? s__('AiGovernance|Blocked') : s__('AiGovernance|Active') }}
        </gl-badge>
      </template>

      <template #cell(actions)="{ item }">
        <span
          v-if="isInherited(item)"
          v-gl-tooltip="$options.i18n.inheritedTooltip"
          data-testid="mcp-server-inherited"
        >
          <gl-button size="small" disabled>{{ $options.i18n.allow }}</gl-button>
        </span>
        <gl-button
          v-else
          size="small"
          :variant="isBlocked(item) ? 'default' : 'danger'"
          :loading="mutatingId === item.id"
          data-testid="mcp-server-toggle-block"
          @click="toggleBlock(item)"
        >
          {{ isBlocked(item) ? $options.i18n.allow : $options.i18n.block }}
        </gl-button>
      </template>
    </gl-table>

    <div
      v-if="pageInfo.hasNextPage || pageInfo.hasPreviousPage"
      class="gl-mt-5 gl-flex gl-justify-center"
    >
      <gl-keyset-pagination v-bind="pageInfo" @prev="handlePrev" @next="handleNext" />
    </div>
  </div>
</template>
