import { visitUrl } from '~/lib/utils/url_utility';
import {
  deduplicateMcpServers,
  connectMcpServer,
} from 'ee/ai/duo_agents_platform/pages/mcp_servers/utils';

jest.mock('~/lib/utils/url_utility');

describe('deduplicateMcpServers', () => {
  const mockMcpServer1 = {
    id: 'gid://gitlab/Ai::Catalog::McpServer/1',
    name: 'Server One',
  };

  const mockMcpServer2 = {
    id: 'gid://gitlab/Ai::Catalog::McpServer/2',
    name: 'Server Two',
  };

  const mockAgent1 = {
    id: 'gid://gitlab/Ai::Catalog::Item/1',
    name: 'Agent One',
    latestVersion: {
      mcpServers: { nodes: [mockMcpServer1, mockMcpServer2] },
    },
  };

  const mockAgent2 = {
    id: 'gid://gitlab/Ai::Catalog::Item/2',
    name: 'Agent Two',
    latestVersion: {
      mcpServers: { nodes: [mockMcpServer1] },
    },
  };

  const buildResponse = (...agents) => ({
    aiCatalogConfiguredItems: {
      nodes: agents.map((agent) => ({ item: agent })),
    },
  });

  it('returns an empty array when there are no configured items', () => {
    expect(deduplicateMcpServers({})).toEqual([]);
    expect(deduplicateMcpServers({ aiCatalogConfiguredItems: { nodes: [] } })).toEqual([]);
  });

  it('returns servers annotated with their agent', () => {
    const result = deduplicateMcpServers(buildResponse(mockAgent1));

    expect(result).toHaveLength(2);
    expect(result[0]).toMatchObject({
      ...mockMcpServer1,
      agents: [{ id: mockAgent1.id, name: mockAgent1.name }],
    });
    expect(result[1]).toMatchObject({
      ...mockMcpServer2,
      agents: [{ id: mockAgent1.id, name: mockAgent1.name }],
    });
  });

  it('deduplicates a server shared across multiple agents and lists all agents', () => {
    const result = deduplicateMcpServers(buildResponse(mockAgent1, mockAgent2));

    expect(result).toHaveLength(2);

    const sharedServer = result.find((s) => s.id === mockMcpServer1.id);
    expect(sharedServer.agents).toHaveLength(2);
    expect(sharedServer.agents).toEqual([
      { id: mockAgent1.id, name: mockAgent1.name },
      { id: mockAgent2.id, name: mockAgent2.name },
    ]);

    const exclusiveServer = result.find((s) => s.id === mockMcpServer2.id);
    expect(exclusiveServer.agents).toHaveLength(1);
  });

  it('skips configured items with no usable agent', () => {
    const agentWithoutVersion = {
      id: 'gid://gitlab/Ai::Catalog::Item/3',
      name: 'Bare Agent',
      latestVersion: null,
    };
    // `null` is a configured item whose `item` the viewer cannot read.
    expect(() => deduplicateMcpServers(buildResponse(agentWithoutVersion, null))).not.toThrow();
    expect(deduplicateMcpServers(buildResponse(agentWithoutVersion, null))).toEqual([]);
  });
});

describe('connectMcpServer', () => {
  it('redirects to the OAuth connect URL with the numeric id and return_to', () => {
    const mcpServer = { id: 'gid://gitlab/Ai::Catalog::McpServer/42' };

    connectMcpServer(mcpServer);

    expect(visitUrl).toHaveBeenCalledWith(
      `/oauth/mcp_connectors/connect?id=42&return_to=${encodeURIComponent(window.location.href)}`,
    );
  });
});
