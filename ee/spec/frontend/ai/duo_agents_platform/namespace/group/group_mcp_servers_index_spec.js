import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import { createAlert } from '~/alert';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import GroupMcpServersIndex from 'ee/ai/duo_agents_platform/namespace/group/group_mcp_servers_index.vue';
import AiCatalogMcpServersIndex from 'ee/ai/duo_agents_platform/pages/mcp_servers/ai_catalog_mcp_servers_index.vue';
import namespaceMcpServersQuery from 'ee/ai/duo_agents_platform/graphql/queries/get_namespace_mcp_servers.query.graphql';

jest.mock('~/alert');

Vue.use(VueApollo);

describe('GroupMcpServersIndex', () => {
  let wrapper;
  let mockApollo;

  const mockGroupId = 42;

  const mockMcpServer1 = {
    __typename: 'AiCatalogMcpServer',
    id: 'gid://gitlab/Ai::Catalog::McpServer/1',
    name: 'Server One',
    description: 'First MCP server',
    url: 'https://example.com/mcp1',
    homepageUrl: 'https://example.com',
    transport: 'HTTP',
    authType: 'OAUTH',
    currentUserConnected: false,
  };

  const mockMcpServer2 = {
    __typename: 'AiCatalogMcpServer',
    id: 'gid://gitlab/Ai::Catalog::McpServer/2',
    name: 'Server Two',
    description: 'Second MCP server',
    url: 'https://example.com/mcp2',
    homepageUrl: null,
    transport: 'HTTP',
    authType: 'NO_AUTH',
    currentUserConnected: false,
  };

  const mockAgent = {
    __typename: 'AiCatalogItem',
    id: 'gid://gitlab/Ai::Catalog::Item/1',
    name: 'Test Agent',
    latestVersion: {
      __typename: 'AiCatalogAgentVersion',
      id: 'gid://gitlab/Ai::Catalog::AgentVersion/1',
      mcpServers: {
        __typename: 'AiCatalogMcpServerConnection',
        nodes: [mockMcpServer1, mockMcpServer2],
      },
    },
  };

  const mockPageInfo = {
    hasNextPage: true,
    hasPreviousPage: false,
    startCursor: 'start_cursor',
    endCursor: 'end_cursor',
  };

  const mockResponse = {
    data: {
      aiCatalogConfiguredItems: {
        __typename: 'AiCatalogConfiguredItemConnection',
        nodes: [
          {
            __typename: 'AiCatalogConfiguredItem',
            id: 'gid://gitlab/Ai::Catalog::ItemConsumer/1',
            item: mockAgent,
          },
        ],
        pageInfo: { __typename: 'PageInfo', ...mockPageInfo },
      },
    },
  };

  const mockQueryHandler = jest.fn().mockResolvedValue(mockResponse);

  const createComponent = ({ provide = {}, queryHandler = mockQueryHandler } = {}) => {
    mockApollo = createMockApollo([[namespaceMcpServersQuery, queryHandler]]);

    wrapper = shallowMountExtended(GroupMcpServersIndex, {
      apolloProvider: mockApollo,
      provide: {
        groupId: mockGroupId,
        ...provide,
      },
    });
  };

  const findMcpServersIndex = () => wrapper.findComponent(AiCatalogMcpServersIndex);

  describe('loading state', () => {
    beforeEach(() => {
      createComponent();
    });

    it('passes isLoading as true while the query is in flight', () => {
      expect(findMcpServersIndex().props('isLoading')).toBe(true);
    });

    it('passes isLoading as false after data is loaded', async () => {
      await waitForPromises();
      expect(findMcpServersIndex().props('isLoading')).toBe(false);
    });
  });

  describe('when query resolves successfully', () => {
    beforeEach(async () => {
      createComponent();
      await waitForPromises();
    });

    it('passes MCP servers with agent info to the index', () => {
      const items = findMcpServersIndex().props('mcpServers');
      expect(items).toHaveLength(2);
    });

    it('passes correct empty state description for the group namespace', () => {
      expect(findMcpServersIndex().props('emptyStateDescription')).toBe(
        'MCP servers associated with agents in this group appear here.',
      );
    });

    it('passes the description prop', () => {
      expect(findMcpServersIndex().props('description')).toBe(
        'MCP servers associated with the agents enabled in your namespace.',
      );
    });

    it('does not show an error alert', () => {
      expect(createAlert).not.toHaveBeenCalled();
    });
  });

  describe('when query fails', () => {
    const errorMessage = 'Network error';

    beforeEach(async () => {
      createComponent({ queryHandler: jest.fn().mockRejectedValue(new Error(errorMessage)) });
      await waitForPromises();
    });

    it('calls createAlert with the error message', () => {
      expect(createAlert).toHaveBeenCalledWith({
        message: errorMessage,
        captureError: true,
      });
    });
  });

  describe('when query fails without an error message', () => {
    beforeEach(async () => {
      createComponent({ queryHandler: jest.fn().mockRejectedValue(new Error()) });
      await waitForPromises();
    });

    it('calls createAlert with the default error message', () => {
      expect(createAlert).toHaveBeenCalledWith({
        message: 'Could not fetch MCP servers.',
        captureError: true,
      });
    });
  });

  describe('when groupId is not provided', () => {
    it('skips the query', () => {
      createComponent({ provide: { groupId: null } });
      expect(mockQueryHandler).not.toHaveBeenCalled();
    });
  });

  describe('pagination', () => {
    beforeEach(async () => {
      createComponent();
      await waitForPromises();
    });

    it('fetches the query with the groupId variable', () => {
      expect(mockQueryHandler).toHaveBeenCalledWith({
        groupId: `gid://gitlab/Group/${mockGroupId}`,
        before: null,
        after: null,
        first: 20,
        last: null,
      });
    });

    it('fetches next page when next-page is emitted', async () => {
      findMcpServersIndex().vm.$emit('next-page');
      await nextTick();

      expect(mockQueryHandler).toHaveBeenCalledWith({
        groupId: `gid://gitlab/Group/${mockGroupId}`,
        before: null,
        after: mockPageInfo.endCursor,
        first: 20,
        last: null,
      });
    });

    it('fetches previous page when prev-page is emitted', async () => {
      findMcpServersIndex().vm.$emit('prev-page');
      await nextTick();

      expect(mockQueryHandler).toHaveBeenCalledWith({
        groupId: `gid://gitlab/Group/${mockGroupId}`,
        after: null,
        before: mockPageInfo.startCursor,
        first: null,
        last: 20,
      });
    });
  });
});
