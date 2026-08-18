import { GlButton, GlIcon, GlTruncate } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { createMockDirective, getBinding } from 'helpers/vue_mock_directive';

import AiCatalogMcpServerListItem from 'ee/ai/catalog/components/ai_catalog_mcp_server_list_item.vue';
import { AI_CATALOG_MCP_SERVERS_SHOW_ROUTE } from 'ee/ai/catalog/router/constants';
import { mockMcpServerListItem } from '../mock_data';

describe('AiCatalogMcpServerListItem', () => {
  let wrapper;

  const createComponent = ({
    item = mockMcpServerListItem,
    showRoute = null,
    showConnect = false,
  } = {}) => {
    wrapper = shallowMountExtended(AiCatalogMcpServerListItem, {
      propsData: {
        item,
        showRoute,
        showConnect,
      },
      directives: {
        GlTooltip: createMockDirective('gl-tooltip'),
      },
      stubs: {
        RouterLink: {
          name: 'RouterLink',
          template: '<a><slot /></a>',
          props: ['to'],
        },
      },
    });
  };

  const findConnectButton = () => wrapper.findComponent(GlButton);
  const findServerName = () => wrapper.find('h2');
  const findDescription = () => wrapper.find('p');
  const findAllIcons = () => wrapper.findAllComponents(GlIcon);
  const findUrlTruncate = () => wrapper.findComponent(GlTruncate);
  const findRouterLink = () => findServerName().findComponent({ name: 'RouterLink' });

  beforeEach(() => {
    createComponent();
  });

  it('renders the server name', () => {
    expect(findServerName().text()).toBe('Test MCP Server');
  });

  it('renders the description', () => {
    expect(findDescription().text()).toBe('A test MCP server description');
  });

  it('renders the server URL', () => {
    expect(findUrlTruncate().props('text')).toBe('https://example.com/mcp');
  });

  it('renders the transport protocol', () => {
    const transportElement = wrapper.findByTestId('mcp-server-transport');
    expect(transportElement.text()).toContain('HTTP');
  });

  it('renders OAuth auth type label', () => {
    const authElement = wrapper.findByTestId('mcp-server-auth-type');
    expect(authElement.text()).toContain('OAuth');
  });

  it('renders correct icons', () => {
    const icons = findAllIcons();
    expect(icons).toHaveLength(3);
    expect(icons.at(0).props('name')).toBe('external-link');
    expect(icons.at(1).props('name')).toBe('status');
    expect(icons.at(2).props('name')).toBe('lock');
  });

  it('links to the MCP server show page', () => {
    expect(findRouterLink().exists()).toBe(true);
    expect(findRouterLink().props('to')).toEqual({
      name: AI_CATALOG_MCP_SERVERS_SHOW_ROUTE,
      params: { id: 1 },
    });
  });

  it('renders tooltips', () => {
    const urlElement = wrapper.findByTestId('mcp-server-url');
    const transportElement = wrapper.findByTestId('mcp-server-transport');
    const authElement = wrapper.findByTestId('mcp-server-auth-type');

    expect(getBinding(urlElement.element, 'gl-tooltip')).toBeDefined();
    expect(getBinding(transportElement.element, 'gl-tooltip')).toBeDefined();
    expect(getBinding(authElement.element, 'gl-tooltip')).toBeDefined();
  });

  describe('when item has no description', () => {
    beforeEach(() => {
      createComponent({ item: { ...mockMcpServerListItem, description: null } });
    });

    it('does not render description', () => {
      expect(findDescription().exists()).toBe(false);
    });
  });

  describe('with NO_AUTH auth type', () => {
    beforeEach(() => {
      createComponent({ item: { ...mockMcpServerListItem, authType: 'NO_AUTH' } });
    });

    it('renders No authentication label', () => {
      const authElement = wrapper.findByTestId('mcp-server-auth-type');
      expect(authElement.text()).toContain('No authentication');
    });
  });

  describe('showRoute prop', () => {
    describe('when showRoute is null', () => {
      beforeEach(() => {
        createComponent();
      });

      it('uses AI_CATALOG_MCP_SERVERS_SHOW_ROUTE by default', () => {
        expect(findRouterLink().props('to')).toMatchObject({
          name: AI_CATALOG_MCP_SERVERS_SHOW_ROUTE,
        });
      });
    });

    describe('when showRoute is provided', () => {
      beforeEach(() => {
        createComponent({ showRoute: 'custom_show_route' });
      });

      it('uses the custom route name', () => {
        expect(findRouterLink().props('to')).toMatchObject({ name: 'custom_show_route' });
      });
    });
  });

  describe('agent count', () => {
    const mockAgents = [
      { id: 'gid://gitlab/Ai::Catalog::Item/1', name: 'Agent Alpha' },
      { id: 'gid://gitlab/Ai::Catalog::Item/2', name: 'Agent Beta' },
      { id: 'gid://gitlab/Ai::Catalog::Item/3', name: 'Agent Gamma' },
    ];

    describe('when item has no agents', () => {
      it('does not render the agent count element', () => {
        createComponent({ item: { ...mockMcpServerListItem, agents: [] } });
        expect(wrapper.findByTestId('mcp-server-agent-count').exists()).toBe(false);
      });

      it('does not render the agent count element when agents is undefined', () => {
        createComponent({ item: { ...mockMcpServerListItem } });
        expect(wrapper.findByTestId('mcp-server-agent-count').exists()).toBe(false);
      });
    });

    describe('when item has agents', () => {
      beforeEach(() => {
        createComponent({ item: { ...mockMcpServerListItem, agents: mockAgents } });
      });

      it('renders the agent count element', () => {
        expect(wrapper.findByTestId('mcp-server-agent-count').exists()).toBe(true);
      });

      it('renders the correct agent count label for multiple agents', () => {
        expect(wrapper.findByTestId('mcp-server-agent-count').text()).toContain('3 agents');
      });

      it('renders the tanuki-ai icon', () => {
        const icons = wrapper.findAllComponents(GlIcon);
        expect(icons.at(icons.length - 1).props('name')).toBe('tanuki-ai');
      });

      it('has a tooltip with all agent names', () => {
        const agentCountEl = wrapper.findByTestId('mcp-server-agent-count');
        const binding = getBinding(agentCountEl.element, 'gl-tooltip');
        expect(binding).toBeDefined();
        expect(binding.value.title).toBe('Agent Alpha, Agent Beta, Agent Gamma');
      });
    });

    describe('when item has more than 5 agents', () => {
      it('truncates the tooltip to 5 names with a remainder count', () => {
        const manyAgents = [1, 2, 3, 4, 5, 6, 7].map((i) => ({
          id: `gid://gitlab/Ai::Catalog::Item/${i}`,
          name: `Agent ${i}`,
        }));
        createComponent({ item: { ...mockMcpServerListItem, agents: manyAgents } });
        const agentCountEl = wrapper.findByTestId('mcp-server-agent-count');
        const binding = getBinding(agentCountEl.element, 'gl-tooltip');
        expect(binding.value.title).toBe('Agent 1, Agent 2, Agent 3, Agent 4, Agent 5, +2 more');
      });
    });

    describe('when item has exactly one agent', () => {
      beforeEach(() => {
        createComponent({ item: { ...mockMcpServerListItem, agents: [mockAgents[0]] } });
      });

      it('renders singular agent count label', () => {
        expect(wrapper.findByTestId('mcp-server-agent-count').text()).toContain('1 agent');
      });
    });
  });

  describe('connect button', () => {
    describe('when showConnect is false', () => {
      beforeEach(() => {
        createComponent({ showConnect: false });
      });

      it('does not render the connect button', () => {
        expect(findConnectButton().exists()).toBe(false);
      });
    });

    describe('when showConnect is true and authType is OAUTH', () => {
      beforeEach(() => {
        createComponent({ showConnect: true });
      });

      it('renders the connect button', () => {
        expect(findConnectButton().exists()).toBe(true);
        expect(findConnectButton().attributes('data-testid')).toBe('connect-mcp-server-button');
      });

      it('renders the external-link icon on the connect button', () => {
        expect(findConnectButton().props('icon')).toBe('external-link');
      });

      it('emits connect event with item when connect button is clicked', async () => {
        await findConnectButton().vm.$emit('click', { preventDefault: jest.fn() });
        expect(wrapper.emitted('connect')).toHaveLength(1);
        expect(wrapper.emitted('connect')[0]).toEqual([mockMcpServerListItem]);
      });
    });

    describe('when showConnect is true but authType is not OAUTH', () => {
      beforeEach(() => {
        createComponent({
          showConnect: true,
          item: { ...mockMcpServerListItem, authType: 'NO_AUTH' },
        });
      });

      it('does not render the connect button for non-OAuth auth type', () => {
        expect(findConnectButton().exists()).toBe(false);
      });
    });
  });
});
