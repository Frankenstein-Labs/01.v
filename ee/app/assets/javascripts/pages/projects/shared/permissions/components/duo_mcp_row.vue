<script>
import { GlButton } from '@gitlab/ui';
import { helpPagePath } from '~/helpers/help_page_helper';
import { n__, s__ } from '~/locale';
import DuoReadinessRow from '~/pages/projects/shared/permissions/components/duo_readiness_row.vue';
import { STATUS_DONE, STATUS_TODO } from '~/pages/projects/shared/permissions/constants';

export default {
  name: 'DuoMcpRow',
  components: { GlButton, DuoReadinessRow },
  props: {
    mcp: {
      type: Object,
      required: true,
    },
  },
  computed: {
    connected() {
      return this.mcp.serversCount > 0;
    },
    status() {
      return this.connected ? STATUS_DONE : STATUS_TODO;
    },
    description() {
      if (!this.connected) {
        return s__(
          'DuoAgentPlatform|Experiment. Agents can connect to tools your team already uses, such as Jira or Linear.',
        );
      }

      return n__(
        'DuoAgentPlatform|%d MCP server is connected. Agents can use it in this project.',
        'DuoAgentPlatform|%d MCP servers are connected. Agents can use them in this project.',
        this.mcp.serversCount,
      );
    },
  },
  docsPath: helpPagePath('user/gitlab_duo/model_context_protocol/ai_catalog_mcp_servers.md'),
  i18n: {
    title: s__('DuoAgentPlatform|MCP servers'),
    viewServers: s__('DuoAgentPlatform|View servers'),
    howToConnect: s__('DuoAgentPlatform|How to connect'),
  },
};
</script>

<template>
  <duo-readiness-row
    :title="$options.i18n.title"
    :description="description"
    :status="status"
    data-testid="mcp-row"
  >
    <gl-button
      v-if="connected"
      category="tertiary"
      size="small"
      :href="mcp.serversPath"
      data-testid="mcp-view-servers-button"
    >
      {{ $options.i18n.viewServers }}
    </gl-button>
    <gl-button
      v-else
      category="secondary"
      size="small"
      icon="external-link"
      :href="$options.docsPath"
      target="_blank"
      data-testid="mcp-how-to-connect-button"
    >
      {{ $options.i18n.howToConnect }}
    </gl-button>
  </duo-readiness-row>
</template>
