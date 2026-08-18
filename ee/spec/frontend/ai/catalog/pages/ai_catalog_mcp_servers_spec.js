import VueApollo from 'vue-apollo';
import Vue from 'vue';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import createMockApollo from 'helpers/mock_apollo_helper';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import waitForPromises from 'helpers/wait_for_promises';
import AiCatalogMcpServers from 'ee/ai/catalog/pages/ai_catalog_mcp_servers.vue';
import AiCatalogListHeader from 'ee/ai/catalog/components/ai_catalog_list_header.vue';
import AiCatalogMcpServerList from 'ee/ai/catalog/components/ai_catalog_mcp_server_list.vue';
import aiCatalogMcpServersQuery from 'ee/ai/catalog/graphql/queries/ai_catalog_mcp_servers.query.graphql';
import { mockMcpServer, mockPageInfo } from '../mock_data';

jest.mock('~/sentry/sentry_browser_wrapper');

Vue.use(VueApollo);

describe('AiCatalogMcpServers', () => {
  let wrapper;
  let mockApollo;

  const mockMcpServers = [
    {
      id: mockMcpServer.id,
      name: mockMcpServer.name,
      description: mockMcpServer.description,
      url: mockMcpServer.url,
      homepageUrl: mockMcpServer.homepageUrl,
      transport: mockMcpServer.transport,
      authType: mockMcpServer.authType,
      oauthClientId: mockMcpServer.oauthClientId,
      createdAt: mockMcpServer.createdAt,
      updatedAt: mockMcpServer.updatedAt,
      // eslint-disable-next-line no-underscore-dangle
      __typename: mockMcpServer.__typename,
    },
    {
      id: 'gid://gitlab/Ai::Catalog::McpServer/2',
      name: 'Another MCP Server',
      description: mockMcpServer.description,
      url: mockMcpServer.url,
      homepageUrl: mockMcpServer.homepageUrl,
      transport: mockMcpServer.transport,
      authType: 'NO_AUTH',
      oauthClientId: null,
      createdAt: mockMcpServer.createdAt,
      updatedAt: mockMcpServer.updatedAt,
      // eslint-disable-next-line no-underscore-dangle
      __typename: mockMcpServer.__typename,
    },
  ];

  const mockMcpServersResponse = {
    data: {
      aiCatalogMcpServers: {
        nodes: mockMcpServers,
        pageInfo: mockPageInfo,
      },
    },
  };

  const mockEmptyMcpServersResponse = {
    data: {
      aiCatalogMcpServers: {
        nodes: [],
        pageInfo: {
          hasNextPage: false,
          hasPreviousPage: false,
          startCursor: null,
          endCursor: null,
        },
      },
    },
  };

  const mockMcpServersQueryHandler = jest.fn().mockResolvedValue(mockMcpServersResponse);

  const createComponent = () => {
    mockApollo = createMockApollo([[aiCatalogMcpServersQuery, mockMcpServersQueryHandler]]);

    wrapper = shallowMountExtended(AiCatalogMcpServers, {
      apolloProvider: mockApollo,
    });
  };

  const findAiCatalogListHeader = () => wrapper.findComponent(AiCatalogListHeader);
  const findAiCatalogMcpServerList = () => wrapper.findComponent(AiCatalogMcpServerList);

  describe('component rendering', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders AiCatalogListHeader component with experiment flag', () => {
      expect(findAiCatalogListHeader().exists()).toBe(true);
      expect(findAiCatalogListHeader().props('isExperiment')).toBe(true);
    });

    it('renders AiCatalogMcpServerList component', () => {
      expect(findAiCatalogMcpServerList().exists()).toBe(true);
    });

    it('passes correct props to AiCatalogMcpServerList', async () => {
      const mcpServerList = findAiCatalogMcpServerList();

      expect(mcpServerList.props('isLoading')).toBe(true);

      await waitForPromises();

      expect(mcpServerList.props('items')).toEqual(mockMcpServers);
      expect(mcpServerList.props('isLoading')).toBe(false);
      expect(mcpServerList.props('emptyStateTitle')).toBe('No MCP servers yet');
      expect(mcpServerList.props('emptyStateDescription')).toBe(
        'Model Context Protocol servers extend agent capabilities with external tools and data sources.',
      );
    });
  });

  describe('Apollo queries', () => {
    beforeEach(() => {
      createComponent();
    });

    it('fetches MCP servers data', () => {
      expect(mockMcpServersQueryHandler).toHaveBeenCalledWith({
        after: null,
        before: null,
        first: 20,
        last: null,
      });
    });
  });

  describe('pagination', () => {
    beforeEach(async () => {
      createComponent();
      await waitForPromises();
    });

    it('passes pageInfo to list component', () => {
      expect(findAiCatalogMcpServerList().props('pageInfo')).toMatchObject(mockPageInfo);
    });

    it('refetches query with correct variables when paging forward', () => {
      findAiCatalogMcpServerList().vm.$emit('next-page');
      expect(mockMcpServersQueryHandler).toHaveBeenCalledWith({
        after: mockPageInfo.endCursor,
        before: null,
        first: 20,
        last: null,
      });
    });

    it('refetches query with correct variables when paging backward', () => {
      findAiCatalogMcpServerList().vm.$emit('prev-page');
      expect(mockMcpServersQueryHandler).toHaveBeenCalledWith({
        after: null,
        before: mockPageInfo.startCursor,
        first: null,
        last: 20,
      });
    });
  });

  describe('empty state', () => {
    beforeEach(async () => {
      mockMcpServersQueryHandler.mockResolvedValue(mockEmptyMcpServersResponse);
      createComponent();
      await waitForPromises();
    });

    it('displays empty state when no MCP servers exist', () => {
      expect(findAiCatalogMcpServerList().props('items')).toEqual([]);
    });
  });

  describe('when query fails', () => {
    it('reports error to Sentry', async () => {
      const error = new Error('GraphQL error');
      mockMcpServersQueryHandler.mockRejectedValue(error);
      createComponent();
      await waitForPromises();

      expect(Sentry.captureException).toHaveBeenCalledWith(error);
    });
  });
});
