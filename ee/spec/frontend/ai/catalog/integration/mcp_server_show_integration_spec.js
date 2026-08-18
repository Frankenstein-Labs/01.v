import waitForPromises from 'helpers/wait_for_promises';
import AiCatalogMcpServersShow from 'ee/ai/catalog/pages/ai_catalog_mcp_servers_show.vue';
import { mockMcpServer } from '../mock_data';
import { createIntegrationWrapper, EXPLORE_PROVIDE, ROUTE_PRESETS } from './helpers';

describe('MCP server — show page integration', () => {
  const mountShowPage = ({ glAbilities = {} } = {}) =>
    createIntegrationWrapper(AiCatalogMcpServersShow, {
      provide: {
        ...EXPLORE_PROVIDE,
        glAbilities,
      },
      props: { aiCatalogMcpServer: mockMcpServer },
      route: ROUTE_PRESETS.mcpServerShow,
    });

  describe('renders server details', () => {
    it('displays server URL, transport, auth type, homepage, and metadata', async () => {
      const { wrapper } = mountShowPage();
      await waitForPromises();

      expect(wrapper.findByTestId('server-name').text()).toContain(mockMcpServer.name);
      expect(wrapper.findByTestId('server-url').text()).toContain(mockMcpServer.url);
      expect(wrapper.findByTestId('server-transport').text()).toContain(mockMcpServer.transport);
      expect(wrapper.findByTestId('server-auth-type').text()).toContain('OAuth');
      expect(wrapper.findByTestId('server-homepage').text()).toContain(mockMcpServer.homepageUrl);
      expect(wrapper.findByTestId('created-on').exists()).toBe(true);
    });
  });

  describe('RBAC', () => {
    it('shows Edit button to organization owners and admins', async () => {
      const { wrapper } = mountShowPage({
        glAbilities: { updateAiCatalogMcpServer: true },
      });
      await waitForPromises();

      expect(wrapper.findByTestId('edit-mcp-server-button').exists()).toBe(true);
    });

    it('hides Edit button from regular members', async () => {
      const { wrapper } = mountShowPage({
        glAbilities: { updateAiCatalogMcpServer: false },
      });
      await waitForPromises();

      expect(wrapper.findByTestId('edit-mcp-server-button').exists()).toBe(false);
    });
  });
});
