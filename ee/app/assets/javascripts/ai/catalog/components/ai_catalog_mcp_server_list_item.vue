<script>
import { GlButton, GlIcon, GlTooltipDirective, GlTruncate } from '@gitlab/ui';
import { n__, s__, sprintf } from '~/locale';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import ConfirmActionModal from '~/vue_shared/components/confirm_action_modal.vue';
import { disconnectMcpServer } from 'ee/ai/duo_agents_platform/pages/mcp_servers/utils';
import { AI_CATALOG_MCP_SERVERS_SHOW_ROUTE } from '../router/constants';

export default {
  name: 'AiCatalogMcpServerListItem',
  components: {
    GlButton,
    GlIcon,
    GlTruncate,
    ConfirmActionModal,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  props: {
    item: {
      type: Object,
      required: true,
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
  emits: ['connect', 'disconnected'],
  data() {
    return {
      showDisconnectModal: false,
    };
  },
  computed: {
    itemId() {
      return getIdFromGraphQLId(this.item.id);
    },
    showItemRoute() {
      return {
        name: this.showRoute || AI_CATALOG_MCP_SERVERS_SHOW_ROUTE,
        params: { id: this.itemId },
      };
    },
    authTypeLabel() {
      if (this.item.authType === 'OAUTH') {
        return s__('AICatalog|OAuth');
      }
      if (this.item.authType === 'NO_AUTH') {
        return s__('AICatalog|No authentication');
      }
      return this.item.authType;
    },
    isOAuth() {
      return this.item.authType === 'OAUTH';
    },
    isConnected() {
      return Boolean(this.item.currentUserConnected);
    },
    shouldShowAuthButton() {
      return this.showConnect && this.isOAuth;
    },
    showConnectButton() {
      return this.shouldShowAuthButton && !this.isConnected;
    },
    showDisconnectButton() {
      return this.shouldShowAuthButton && this.isConnected;
    },
    agents() {
      return this.item.agents || [];
    },
    agentCount() {
      return this.agents.length;
    },
    agentCountLabel() {
      return n__('AICatalog|%d agent', 'AICatalog|%d agents', this.agentCount);
    },
    agentNamesTooltip() {
      const MAX_NAMES = 5;
      const names = this.agents.map((a) => a.name);
      const remainder = names.length - MAX_NAMES;

      return (
        names.slice(0, MAX_NAMES).join(', ') +
        (remainder > 0
          ? `, +${n__('AICatalog|%d more', 'AICatalog|%d more', remainder).replace('%d', remainder)}`
          : '')
      );
    },
    disconnectModalTitle() {
      return sprintf(s__('AICatalog|Disconnect %{name}?'), { name: this.item.name });
    },
    disconnectModalMessage() {
      return s__(
        'AICatalog|Existing agent chats will continue to reference content already retrieved from this server. However, agents will no longer be able to fetch new content or perform any actions. You can reconnect at any time.',
      );
    },
  },
  methods: {
    handleConnect() {
      this.$emit('connect', this.item);
    },
    handleDisconnectClick() {
      this.showDisconnectModal = true;
    },
    async handleDisconnect() {
      try {
        await disconnectMcpServer(this.item);
        this.$emit('disconnected', this.item);
      } catch {
        throw new Error(s__('AICatalog|Failed to disconnect from server. Please try again.'));
      }
    },
  },
};
</script>

<template>
  <li
    class="gl-border-b gl-relative gl-cursor-pointer gl-p-4 gl-pt-5 gl-transition-background hover:gl-bg-subtle"
    :data-testid="`mcp-server-item-${item.id}`"
  >
    <div class="gl-flex gl-items-start gl-justify-between gl-gap-4">
      <div class="gl-flex gl-min-w-0 gl-flex-1 gl-flex-col gl-gap-3">
        <h2 class="gl-heading-5 gl-m-0 gl-line-clamp-2 gl-text-ellipsis gl-p-0 @sm:gl-line-clamp-1">
          <router-link
            class="!gl-text-default !gl-no-underline gl-stretched-link"
            :to="showItemRoute"
          >
            {{ item.name }}
          </router-link>
        </h2>
        <p
          v-if="item.description"
          class="gl-m-0 gl-line-clamp-3 gl-text-ellipsis gl-p-0 gl-text-subtle @sm:gl-line-clamp-2 @md:gl-line-clamp-1"
        >
          {{ item.description }}
        </p>
        <div class="gl-flex gl-shrink gl-flex-wrap gl-gap-4">
          <div
            v-gl-tooltip
            :title="s__('AICatalog|Server URL')"
            data-testid="mcp-server-url"
            class="gl-flex gl-items-center gl-gap-2"
          >
            <gl-icon name="external-link" variant="subtle" :size="14" />
            <gl-truncate class="gl-max-w-40 gl-pt-px gl-text-subtle" :text="item.url" />
          </div>
          <div
            v-gl-tooltip
            :title="s__('AICatalog|Transport protocol')"
            data-testid="mcp-server-transport"
            class="gl-flex gl-items-center gl-gap-2"
          >
            <gl-icon name="status" variant="subtle" :size="14" />
            <span class="gl-whitespace-nowrap gl-pt-px gl-text-subtle">{{ item.transport }}</span>
          </div>
          <div
            v-gl-tooltip
            :title="s__('AICatalog|Authentication type')"
            data-testid="mcp-server-auth-type"
            class="gl-flex gl-items-center gl-gap-2"
          >
            <gl-icon name="lock" variant="subtle" :size="14" />
            <span class="gl-whitespace-nowrap gl-pt-px gl-text-subtle">{{ authTypeLabel }}</span>
          </div>
          <div
            v-if="agentCount > 0"
            v-gl-tooltip="{ title: agentNamesTooltip, placement: 'top' }"
            data-testid="mcp-server-agent-count"
            class="gl-relative gl-z-1 gl-flex gl-items-center gl-gap-2"
          >
            <gl-icon name="tanuki-ai" variant="subtle" :size="14" />
            <span class="gl-whitespace-nowrap gl-pt-px gl-text-subtle">{{ agentCountLabel }}</span>
          </div>
        </div>
      </div>
      <gl-button
        v-if="showConnectButton"
        class="gl-z-1 gl-self-center"
        icon="external-link"
        data-testid="connect-mcp-server-button"
        @click.prevent="handleConnect"
      >
        {{ s__('AICatalog|Connect') }}
      </gl-button>
      <gl-button
        v-if="showDisconnectButton"
        class="gl-z-1 gl-self-center"
        variant="danger"
        category="secondary"
        data-testid="disconnect-mcp-server-button"
        @click.prevent="handleDisconnectClick"
      >
        {{ s__('AICatalog|Disconnect') }}
      </gl-button>
    </div>

    <confirm-action-modal
      v-if="showDisconnectModal"
      modal-id="disconnect-mcp-server-modal"
      :title="disconnectModalTitle"
      :action-text="s__('AICatalog|Disconnect')"
      :action-fn="handleDisconnect"
      @close="showDisconnectModal = false"
    >
      {{ disconnectModalMessage }}
    </confirm-action-modal>
  </li>
</template>
