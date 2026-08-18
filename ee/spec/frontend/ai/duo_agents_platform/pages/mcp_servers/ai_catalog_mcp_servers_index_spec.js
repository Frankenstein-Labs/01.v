import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import AiCatalogMcpServersIndex from 'ee/ai/duo_agents_platform/pages/mcp_servers/ai_catalog_mcp_servers_index.vue';
import AiCatalogListHeader from 'ee/ai/catalog/components/ai_catalog_list_header.vue';
import AiCatalogMcpServerList from 'ee/ai/catalog/components/ai_catalog_mcp_server_list.vue';
import { MCP_SERVERS_SHOW_ROUTE } from 'ee/ai/duo_agents_platform/router/constants';

Vue.use(VueApollo);

describe('AiCatalogMcpServersIndex', () => {
  let wrapper;

  const mockMcpServer1 = {
    id: 'gid://gitlab/Ai::Catalog::McpServer/1',
    name: 'Server One',
    agents: [],
  };

  const mockPageInfo = {
    hasNextPage: true,
    hasPreviousPage: false,
    startCursor: 'start_cursor',
    endCursor: 'end_cursor',
  };

  const defaultProps = {
    mcpServers: [mockMcpServer1],
    pageInfo: mockPageInfo,
    isLoading: false,
    emptyStateDescription: 'MCP servers associated with agents appear here.',
  };

  const createComponent = (props = {}) => {
    wrapper = shallowMountExtended(AiCatalogMcpServersIndex, {
      propsData: { ...defaultProps, ...props },
    });
  };

  const findListHeader = () => wrapper.findComponent(AiCatalogListHeader);
  const findMcpServerList = () => wrapper.findComponent(AiCatalogMcpServerList);

  it('renders the list header', () => {
    createComponent();
    expect(findListHeader().props('isExperiment')).toBe(true);
  });

  describe('loading state', () => {
    it('passes isLoading as true to the list while loading', () => {
      createComponent({ isLoading: true });
      expect(findMcpServerList().props('isLoading')).toBe(true);
    });

    it('passes isLoading as false to the list when not loading', () => {
      createComponent({ isLoading: false });
      expect(findMcpServerList().props('isLoading')).toBe(false);
    });
  });

  describe('when not loading', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders the MCP server list', () => {
      expect(findMcpServerList().exists()).toBe(true);
    });

    it('passes mcpServers as items to the list', () => {
      expect(findMcpServerList().props('items')).toEqual([mockMcpServer1]);
    });

    it('passes pageInfo to the list', () => {
      expect(findMcpServerList().props('pageInfo')).toMatchObject(mockPageInfo);
    });

    it('passes showRoute prop with MCP_SERVERS_SHOW_ROUTE to the list', () => {
      expect(findMcpServerList().props('showRoute')).toBe(MCP_SERVERS_SHOW_ROUTE);
    });

    it('passes showConnect as true to the list', () => {
      expect(findMcpServerList().props('showConnect')).toBe(true);
    });

    it('passes correct empty state title to the list', () => {
      expect(findMcpServerList().props('emptyStateTitle')).toBe('No MCP servers found');
    });

    it('passes emptyStateDescription to the list', () => {
      expect(findMcpServerList().props('emptyStateDescription')).toBe(
        defaultProps.emptyStateDescription,
      );
    });

    it('does not render a description in the header when description prop is not set', () => {
      expect(findListHeader().text()).not.toContain('MCP servers associated');
    });
  });

  describe('when description prop is provided', () => {
    it('renders the description in the header', () => {
      createComponent({
        description: 'MCP servers associated with the agents enabled in your project.',
      });
      expect(findListHeader().text()).toContain(
        'MCP servers associated with the agents enabled in your project.',
      );
    });
  });

  describe('events', () => {
    beforeEach(() => {
      createComponent();
    });

    it('emits next-page when the list emits next-page', () => {
      findMcpServerList().vm.$emit('next-page');
      expect(wrapper.emitted('next-page')).toHaveLength(1);
    });

    it('emits prev-page when the list emits prev-page', () => {
      findMcpServerList().vm.$emit('prev-page');
      expect(wrapper.emitted('prev-page')).toHaveLength(1);
    });

    it('emits connect with the server when the list emits connect', () => {
      findMcpServerList().vm.$emit('connect', mockMcpServer1);
      expect(wrapper.emitted('connect')).toEqual([[mockMcpServer1]]);
    });
  });
});
