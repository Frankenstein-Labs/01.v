<script>
import { GlIcon } from '@gitlab/ui';
import { s__ } from '~/locale';
import { convertToGraphQLId } from '~/graphql_shared/utils';
import { TYPENAME_GROUP, TYPENAME_PROJECT } from '~/graphql_shared/constants';
import { joinPaths } from '~/lib/utils/url_utility';
import getDashboardConfiguredAgentsQuery from 'ee/ai/governance/graphql/queries/get_dashboard_configured_agents.query.graphql';
import DashboardListCard from './dashboard_list_card.vue';

const LIMIT = 5;
const AGENT_ITEM_TYPE = 'AGENT';

export default {
  name: 'AgentInventoryCard',
  components: {
    DashboardListCard,
    GlIcon,
  },
  inject: {
    groupId: { default: null },
    projectId: { default: null },
    groupFullPath: { default: null },
    projectFullPath: { default: null },
  },
  apollo: {
    configuredItems: {
      query: getDashboardConfiguredAgentsQuery,
      variables() {
        const base = { itemTypes: [AGENT_ITEM_TYPE], first: LIMIT };

        return this.isProjectMode
          ? { ...base, projectId: convertToGraphQLId(TYPENAME_PROJECT, this.projectId) }
          : { ...base, groupId: convertToGraphQLId(TYPENAME_GROUP, this.groupId) };
      },
      update(data) {
        return data.aiCatalogConfiguredItems?.nodes || [];
      },
      error() {
        this.hasError = true;
      },
    },
  },
  data() {
    return {
      configuredItems: [],
      hasError: false,
    };
  },
  computed: {
    isProjectMode() {
      // Base this on projectId, since that is what the query variables use to
      // build the ProjectID; keeps the mode decision and the query consistent.
      return Boolean(this.projectId);
    },
    loading() {
      return this.$apollo.queries.configuredItems.loading;
    },
    agents() {
      return (this.configuredItems || [])
        .filter((node) => node.item)
        .map((node) => ({
          id: node.id,
          name: node.item.name,
          subtitle: node.item.description || '',
        }));
    },
    isEmpty() {
      return !this.loading && !this.hasError && this.agents.length === 0;
    },
    errorText() {
      return this.hasError ? s__('AiGovernance|Failed to load agent inventory.') : '';
    },
    viewAllHref() {
      const namespacePath = this.isProjectMode
        ? this.projectFullPath
        : joinPaths('groups', this.groupFullPath);

      return joinPaths('/', namespacePath, '-', 'automate', 'agents');
    },
  },
  i18n: {
    title: s__('AiGovernance|AI agent inventory'),
    viewAll: s__('AiGovernance|View all agents'),
    empty: s__('AiGovernance|No agents configured yet.'),
  },
};
</script>

<template>
  <dashboard-list-card
    :title="$options.i18n.title"
    :view-all-text="$options.i18n.viewAll"
    :view-all-href="viewAllHref"
    :loading="loading"
    :error-text="errorText"
    :is-empty="isEmpty"
    :empty-text="$options.i18n.empty"
  >
    <li
      v-for="agent in agents"
      :key="agent.id"
      class="gl-border-b gl-flex gl-items-center gl-gap-3 gl-border-section gl-p-4 last:gl-border-b-0"
      data-testid="agent-inventory-row"
    >
      <gl-icon name="tanuki-ai" class="gl-shrink-0 gl-text-subtle" />
      <span class="gl-min-w-0">
        <span class="gl-block gl-truncate gl-font-bold">{{ agent.name }}</span>
        <span class="gl-block gl-truncate gl-text-sm gl-text-subtle">{{ agent.subtitle }}</span>
      </span>
    </li>
  </dashboard-list-card>
</template>
