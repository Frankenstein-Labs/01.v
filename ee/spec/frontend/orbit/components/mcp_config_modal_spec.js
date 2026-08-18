import { GlCollapsibleListbox, GlTabs } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import McpConfigModal from 'ee/orbit/components/mcp_config_modal.vue';

describe('McpConfigModal', () => {
  let wrapper;

  const MCP_ENDPOINT = 'https://gdk.test/orbit/mcp';

  const createComponent = ({ props = {} } = {}) => {
    wrapper = shallowMountExtended(McpConfigModal, {
      propsData: {
        mcpEndpoint: MCP_ENDPOINT,
        visible: true,
        ...props,
      },
    });
  };

  const findCliCopyButton = () => wrapper.findComponentByTestId('copy-cli-command-btn');
  const findManualCopyButton = () => wrapper.findComponentByTestId('copy-manual-config-btn');
  const findToolCopyButtons = () => wrapper.findAllComponentsByTestId('copy-tool-name-btn');
  const findHostListbox = () => wrapper.findComponent(GlCollapsibleListbox);
  const findManualTabButton = () => wrapper.findComponentByTestId('manual-config-tab-btn');
  const findViewTabs = () => wrapper.findComponent(GlTabs);

  const selectHost = (value) => findHostListbox().vm.$emit('select', value);
  const selectManualTab = () => findManualTabButton().vm.$emit('click');
  const showToolsTab = () => findViewTabs().vm.$emit('input', 1);

  describe('CLI command copy button', () => {
    it('does not render for gitlab-duo (no CLI command available)', () => {
      createComponent();

      expect(findCliCopyButton().exists()).toBe(false);
    });

    it.each([
      ['claude-code', `claude mcp add orbit ${MCP_ENDPOINT} \\\n   --transport http`],
      ['claude-desktop', `npx -y mcp-remote ${MCP_ENDPOINT}`],
      ['cursor', `npx -y mcp-remote ${MCP_ENDPOINT}`],
      ['codex', `codex mcp add orbit \\\n   --url ${MCP_ENDPOINT}`],
    ])('passes the %s CLI command as text to SimpleCopyButton', async (host, expectedCommand) => {
      createComponent();
      await selectHost(host);

      expect(findCliCopyButton().props('text')).toBe(expectedCommand);
      expect(findCliCopyButton().props('title')).toBe('Copy command');
    });

    it('hides when the manual tab is selected', async () => {
      createComponent();
      await selectHost('claude-code');
      await selectManualTab();

      expect(findCliCopyButton().exists()).toBe(false);
    });
  });

  describe('manual config copy button', () => {
    it('renders for gitlab-duo with the duo MCP config JSON', () => {
      createComponent();

      const button = findManualCopyButton();
      expect(button.exists()).toBe(true);
      expect(button.props('text')).toBe(
        JSON.stringify(
          {
            mcpServers: {
              orbit: { type: 'http', url: MCP_ENDPOINT, approvedTools: true },
            },
          },
          null,
          2,
        ),
      );
      expect(button.props('title')).toBe('Copy configuration');
    });

    it.each([
      [
        'claude-code',
        JSON.stringify({ mcpServers: { orbit: { type: 'http', url: MCP_ENDPOINT } } }, null, 2),
      ],
      [
        'cursor',
        JSON.stringify({ mcpServers: { orbit: { type: 'http', url: MCP_ENDPOINT } } }, null, 2),
      ],
      [
        'claude-desktop',
        JSON.stringify(
          {
            mcpServers: {
              orbit: { type: 'stdio', command: 'npx', args: ['-y', 'mcp-remote', MCP_ENDPOINT] },
            },
          },
          null,
          2,
        ),
      ],
      ['codex', `[mcp_servers.orbit]\nurl = "${MCP_ENDPOINT}"`],
    ])(
      'passes the %s manual config to SimpleCopyButton after switching to the manual tab',
      async (host, expectedConfig) => {
        createComponent();
        await selectHost(host);
        await selectManualTab();

        expect(findManualCopyButton().props('text')).toBe(expectedConfig);
      },
    );

    it('renders for opencode (no CLI command) with the opencode remote MCP config JSON', async () => {
      createComponent();
      await selectHost('opencode');

      expect(findHostListbox().props('toggleText')).toBe('OpenCode');
      expect(findCliCopyButton().exists()).toBe(false);
      expect(findManualCopyButton().props('text')).toBe(
        JSON.stringify(
          {
            mcp: {
              orbit: { type: 'remote', url: MCP_ENDPOINT, enabled: true },
            },
          },
          null,
          2,
        ),
      );
    });
  });

  describe('tools tab', () => {
    const tools = [
      { name: 'orbit_search', description: 'Search' },
      { name: 'orbit_describe', description: 'Describe' },
    ];

    it('renders one SimpleCopyButton per tool with the tool name as text', async () => {
      createComponent({ props: { tools } });
      await showToolsTab();

      const buttons = findToolCopyButtons();
      expect(buttons).toHaveLength(tools.length);
      expect(buttons.at(0).props('text')).toBe('orbit_search');
      expect(buttons.at(1).props('text')).toBe('orbit_describe');
      expect(buttons.at(0).props('title')).toBe('Copy tool name');
      expect(buttons.at(1).props('title')).toBe('Copy tool name');
    });

    it('renders no copy buttons when the tools list is empty', async () => {
      createComponent();
      await showToolsTab();

      expect(findToolCopyButtons()).toHaveLength(0);
    });
  });
});
