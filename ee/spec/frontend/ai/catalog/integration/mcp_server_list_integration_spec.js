import waitForPromises from 'helpers/wait_for_promises';
import AiCatalogMcpServers from 'ee/ai/catalog/pages/ai_catalog_mcp_servers.vue';
import aiCatalogMcpServersQuery from 'ee/ai/catalog/graphql/queries/ai_catalog_mcp_servers.query.graphql';
import {
  mockMcpServers,
  mockMcpServersQueryResponse,
  mockMcpServersEmptyQueryResponse,
} from '../mock_data';
import { createIntegrationWrapper, EXPLORE_PROVIDE, ROUTE_PRESETS } from './helpers';

const createQueryHandler = (response) => jest.fn().mockResolvedValue(response);

describe('MCP server — list page integration', () => {
  const mountListPage = ({ queryHandler } = {}) => {
    const handler = queryHandler || createQueryHandler(mockMcpServersQueryResponse);
    return createIntegrationWrapper(AiCatalogMcpServers, {
      provide: EXPLORE_PROVIDE,
      apolloHandlers: [[aiCatalogMcpServersQuery, handler]],
      route: ROUTE_PRESETS.mcpServerList,
    });
  };

  it('renders MCP server items from query response', async () => {
    const { wrapper } = mountListPage();
    await waitForPromises();

    expect(wrapper.findAll('[data-testid^="mcp-server-item-"]')).toHaveLength(
      mockMcpServers.length,
    );

    const [first] = mockMcpServers;
    const firstItem = wrapper.findByTestId(`mcp-server-item-${first.id}`);
    expect(firstItem.text()).toContain(first.name);
    expect(firstItem.text()).toContain(first.description);
    expect(firstItem.find('[data-testid="mcp-server-url"]').text()).toContain(first.url);
    expect(firstItem.find('[data-testid="mcp-server-transport"]').text()).toContain(
      first.transport,
    );
    expect(firstItem.find('[data-testid="mcp-server-auth-type"]').text()).toContain(first.authType);
  });

  it('shows empty state when no servers exist', async () => {
    const { wrapper } = mountListPage({
      queryHandler: createQueryHandler(mockMcpServersEmptyQueryResponse),
    });
    await waitForPromises();

    expect(wrapper.findAll('[data-testid^="mcp-server-item-"]')).toHaveLength(0);
    expect(wrapper.text()).toContain('No MCP servers yet');
  });

  it('fetches next page with correct cursor variables', async () => {
    const handler = createQueryHandler(mockMcpServersQueryResponse);
    const { wrapper } = mountListPage({ queryHandler: handler });
    await waitForPromises();

    const nextButton = wrapper.findByTestId('nextButton');
    expect(nextButton.exists()).toBe(true);

    await nextButton.trigger('click');
    await waitForPromises();

    expect(handler).toHaveBeenCalledWith(
      expect.objectContaining({
        after: mockMcpServersQueryResponse.data.aiCatalogMcpServers.pageInfo.endCursor,
        first: 20,
      }),
    );
  });

  it('fetches previous page with correct cursor variables', async () => {
    const prevPageResponse = {
      data: {
        aiCatalogMcpServers: {
          ...mockMcpServersQueryResponse.data.aiCatalogMcpServers,
          pageInfo: {
            hasNextPage: true,
            hasPreviousPage: true,
            startCursor: 'startCursor',
            endCursor: 'endCursor',
            __typename: 'PageInfo',
          },
        },
      },
    };
    const handler = createQueryHandler(prevPageResponse);
    const { wrapper } = mountListPage({ queryHandler: handler });
    await waitForPromises();

    const prevButton = wrapper.findByTestId('prevButton');
    expect(prevButton.exists()).toBe(true);

    await prevButton.trigger('click');
    await waitForPromises();

    expect(handler).toHaveBeenCalledWith(
      expect.objectContaining({
        before: 'startCursor',
        last: 20,
      }),
    );
  });
});
