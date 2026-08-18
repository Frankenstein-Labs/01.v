import axios from '~/lib/utils/axios_utils';
import { visitUrl } from '~/lib/utils/url_utility';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';

/**
 * Transforms a GraphQL aiCatalogConfiguredItems response into a deduplicated
 * list of MCP servers, each annotated with the agents that reference it.
 *
 * @param {Object} data - Raw GraphQL response data
 * @returns {Array} Deduplicated MCP server objects with an `agents` array
 */
export const deduplicateMcpServers = (data) => {
  const configuredItems = data?.aiCatalogConfiguredItems?.nodes || [];

  const mcpServersMap = configuredItems.reduce((map, { item: agent }) => {
    const servers = agent?.latestVersion?.mcpServers?.nodes || [];

    servers.forEach((server) => {
      const existing = map.get(server.id) ?? { ...server, agents: [] };
      existing.agents.push({ id: agent.id, name: agent.name });
      map.set(server.id, existing);
    });

    return map;
  }, new Map());

  return Array.from(mcpServersMap.values());
};

/**
 * Redirects the user to the OAuth MCP connector flow for the given server.
 *
 * @param {Object} mcpServer - MCP server object with a GraphQL `id`
 */
export const connectMcpServer = (mcpServer) => {
  const mcpServerId = getIdFromGraphQLId(mcpServer.id);
  const returnTo = encodeURIComponent(window.location.href);
  // eslint-disable-next-line @gitlab/no-hardcoded-urls
  visitUrl(`/oauth/mcp_connectors/connect?id=${mcpServerId}&return_to=${returnTo}`);
};

/**
 * Disconnects the current user from the given MCP server by revoking the stored token.
 *
 * @param {Object} mcpServer - MCP server object with a GraphQL `id`
 * @returns {Promise} Resolves on success, rejects with an error message on failure
 */
export const disconnectMcpServer = (mcpServer) => {
  const mcpServerId = getIdFromGraphQLId(mcpServer.id);
  // eslint-disable-next-line @gitlab/no-hardcoded-urls
  return axios.post(`/oauth/mcp_connectors/disconnect`, { id: mcpServerId });
};
