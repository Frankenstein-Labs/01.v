<script>
import { joinPaths } from '~/lib/utils/url_utility';
import { logError } from '~/lib/logger';
import { getSlotFunction, normalizeRender } from '~/lib/utils/vue3compat/normalize_render';

import organizationWorkspacesClusterAgentsQuery from '../graphql/queries/organization_workspaces_cluster_agents.query.graphql';
import mappedOrganizationClusterAgentsQuery from '../graphql/queries/organization_mapped_agents.query.graphql';

export default normalizeRender({
  props: {
    organizationId: {
      type: String,
      required: true,
    },
  },
  data() {
    return {
      mappedAgentsLoaded: false,
      mappedAgents: null,
      rawAgents: null,
      error: null,
      beforeCursor: null,
      afterCursor: null,
      hasNextPage: false,
      hasPreviousPage: false,
    };
  },
  computed: {
    agents() {
      if (!this.rawAgents || !this.mappedAgents) return null;

      return this.rawAgents.map((agent) => ({
        ...agent,
        isMapped: this.mappedAgents.has(agent.id),
      }));
    },
  },
  apollo: {
    mappedAgents: {
      query: mappedOrganizationClusterAgentsQuery,
      variables() {
        return {
          organizationId: this.organizationId,
        };
      },
      skip() {
        return !this.organizationId;
      },
      error(error) {
        logError(error);
        this.error = error;
      },
      update(data) {
        this.error = null;

        const mappedAgentIds = data.organization.mappedAgents.nodes?.map((agent) => agent.id) || [];

        this.mappedAgentsLoaded = true;
        return new Set(mappedAgentIds);
      },
    },
    rawAgents: {
      query: organizationWorkspacesClusterAgentsQuery,
      variables() {
        return {
          organizationId: this.organizationId,
        };
      },
      skip() {
        return !this.mappedAgentsLoaded;
      },
      error(error) {
        logError(error);
        this.error = error;
      },
      update(data) {
        this.error = null;

        const { pageInfo, nodes } = data.organization.organizationWorkspacesClusterAgents;

        this.hasNextPage = pageInfo.hasNextPage;
        this.hasPreviousPage = pageInfo.hasPreviousPage;
        this.beforeCursor = pageInfo.startCursor;
        this.afterCursor = pageInfo.endCursor;

        return nodes.map((agent) => ({
          id: agent.id,
          name: agent.name,
          url: joinPaths(window.gon.gitlab_url, agent.webPath),
          group: agent.project?.group?.name || '',
          project: agent.project?.name || '',
          isConnected: Boolean(agent.connections?.nodes.length),
          workspacesEnabled: Boolean(agent.workspacesAgentConfig?.enabled),
        }));
      },
    },
  },
  methods: {
    nextPage() {
      this.$apollo.queries.rawAgents.refetch({
        organizationId: this.organizationId,
        before: null,
        after: this.afterCursor,
      });
    },
    prevPage() {
      this.$apollo.queries.rawAgents.refetch({
        organizationId: this.organizationId,
        before: this.beforeCursor,
        after: null,
      });
    },
    getPaginationData() {
      if (this.error) return null;

      return {
        show: this.hasNextPage || this.hasPreviousPage,
        hasPreviousPage: this.hasPreviousPage,
        hasNextPage: this.hasNextPage,
        nextPage: this.nextPage,
        prevPage: this.prevPage,
      };
    },
  },
  render() {
    return getSlotFunction(this)?.({
      loading: this.$apollo.loading,
      error: this.error,
      agents: this.agents,
      pagination: this.getPaginationData(),
    });
  },
});
</script>
