<script>
import { GlTabs, GlTab, GlBadge } from '@gitlab/ui';
import { createAlert } from '~/alert';
import { s__, sprintf } from '~/locale';
import {
  AGENT_MAPPING_STATUS_MAPPED,
  ALERT_CONTAINER_CLASSNAME,
  ALERT_CONTAINER_SELECTOR,
} from '../constants';
import AgentsTable from './agents_table.vue';
import GetAgentsWithMappingStatusQuery from './get_agents_with_mapping_status_query.vue';

const NO_ALLOWED_AGENTS_MESSAGE = s__(
  'Workspaces|This group has no available agents. Select the %{strongStart}All agents%{strongEnd} tab and allow at least one agent.',
);
const NO_AGENTS_MESSAGE = s__('Workspaces|This group has no agents. Start by creating an agent.');

export default {
  name: 'AgentMapping',
  components: {
    GlBadge,
    GlTabs,
    GlTab,
    AgentsTable,
    GetAgentsWithMappingStatusQuery,
  },
  inject: {
    namespace: {
      default: '',
    },
  },
  data() {
    return {
      agents: [],
      queryErrored: false,
      namespaceId: '',
    };
  },
  computed: {
    allowedAgents() {
      return this.agents.filter((agent) => agent.mappingStatus === AGENT_MAPPING_STATUS_MAPPED);
    },
    allowedAgentsTableEmptyMessage() {
      return this.agents.length
        ? sprintf(
            NO_ALLOWED_AGENTS_MESSAGE,
            { strongStart: '<strong>', strongEnd: '</strong>' },
            false,
          )
        : NO_AGENTS_MESSAGE;
    },
  },
  methods: {
    onQueryResult({ agents, namespaceId }) {
      this.namespaceId = namespaceId;
      this.agents = agents;
    },
    onErrorResult() {
      this.queryErrored = true;
      createAlert({
        message: s__('Workspaces|Could not load available agents. Refresh the page to try again.'),
        containerSelector: ALERT_CONTAINER_SELECTOR,
      });
    },
  },
  NO_AGENTS_MESSAGE,
  ALERT_CONTAINER_CLASSNAME,
};
</script>
<template>
  <get-agents-with-mapping-status-query
    :namespace="namespace"
    @result="onQueryResult"
    @error="onErrorResult"
  >
    <template #default="{ loading }">
      <div class="gl-pt-4">
        <div :class="$options.ALERT_CONTAINER_CLASSNAME"></div>
        <gl-tabs lazy>
          <gl-tab data-testid="allowed-agents-tab">
            <template #title>
              <span>{{ s__('Workspaces|Allowed agents') }}</span>
              <gl-badge class="gl-tab-counter-badge">{{ allowedAgents.length }}</gl-badge>
              <span class="gl-sr-only">{{ __('agents') }}</span>
            </template>
            <agents-table
              v-if="!queryErrored"
              data-testid="allowed-agents-table"
              :agents="allowedAgents"
              :namespace-id="namespaceId"
              :is-loading="loading"
              :empty-state-message="allowedAgentsTableEmptyMessage"
            />
          </gl-tab>
          <gl-tab data-testid="all-agents-tab">
            <template #title>
              <span>{{ s__('Workspaces|All agents') }}</span>
              <gl-badge class="gl-tab-counter-badge">{{ agents.length }}</gl-badge>
              <span class="gl-sr-only">{{ __('agents') }}</span>
            </template>
            <agents-table
              v-if="!queryErrored"
              data-testid="all-agents-table"
              display-mapping-status
              :agents="agents"
              :namespace-id="namespaceId"
              :is-loading="loading"
              :empty-state-message="$options.NO_AGENTS_MESSAGE"
            />
          </gl-tab>
        </gl-tabs>
      </div>
    </template>
  </get-agents-with-mapping-status-query>
</template>
