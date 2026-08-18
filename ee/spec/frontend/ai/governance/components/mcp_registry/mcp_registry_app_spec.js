import Vue from 'vue';
import VueApollo from 'vue-apollo';
import {
  GlAlert,
  GlBadge,
  GlButton,
  GlKeysetPagination,
  GlLoadingIcon,
  GlLink,
  GlTruncate,
} from '@gitlab/ui';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import McpRegistryApp from 'ee/ai/governance/components/mcp_registry/mcp_registry_app.vue';
import getMcpServersQuery from 'ee/ai/governance/graphql/queries/get_mcp_servers.query.graphql';
import setMcpServerBlockMutation from 'ee/ai/governance/graphql/mutations/set_mcp_server_block.mutation.graphql';

Vue.use(VueApollo);

const GROUP_FULL_PATH = 'gitlab-org';
const PROJECT_FULL_PATH = 'gitlab-org/gitlab';

const mockPageInfo = {
  hasNextPage: true,
  hasPreviousPage: false,
  startCursor: 'cursor-start',
  endCursor: 'cursor-end',
  __typename: 'PageInfo',
};

const server = ({ id, name, description = null, authType = 'OAUTH', blockStatus = 'ACTIVE' }) => ({
  id: `gid://gitlab/Ai::Catalog::McpServer/${id}`,
  name,
  description,
  url: `https://${name}.mcp.io`,
  authType,
  transport: 'HTTP',
  blockStatus,
  __typename: 'AiCatalogMcpServer',
});

const mockServers = {
  nodes: [
    server({ id: 1, name: 'figma', description: 'Figma access', blockStatus: 'ACTIVE' }),
    server({ id: 2, name: 'slack', description: 'Slack', blockStatus: 'BLOCKED' }),
    server({ id: 3, name: 'jira', authType: 'NO_AUTH', blockStatus: 'BLOCKED_BY_ANCESTOR' }),
  ],
  pageInfo: mockPageInfo,
  __typename: 'AiCatalogMcpServerConnection',
};

const mockQueryResponse = (mcpServers = mockServers) => ({
  data: { aiCatalogMcpServers: mcpServers },
});

const mockMutationResponse = (blockStatus = 'BLOCKED', errors = []) => ({
  data: {
    aiCatalogMcpServerSetBlock: {
      errors,
      mcpServer: {
        id: 'gid://gitlab/Ai::Catalog::McpServer/1',
        blockStatus,
        __typename: 'AiCatalogMcpServer',
      },
      __typename: 'AiCatalogMcpServerSetBlockPayload',
    },
  },
});

describe('McpRegistryApp', () => {
  let wrapper;
  let queryHandler;
  let mutationHandler;

  const createComponent = ({
    queryHandlerImpl = jest.fn().mockResolvedValue(mockQueryResponse()),
    mutationHandlerImpl = jest.fn().mockResolvedValue(mockMutationResponse()),
    provide = { groupFullPath: GROUP_FULL_PATH, projectFullPath: '' },
  } = {}) => {
    queryHandler = queryHandlerImpl;
    mutationHandler = mutationHandlerImpl;

    const apolloProvider = createMockApollo([
      [getMcpServersQuery, queryHandler],
      [setMcpServerBlockMutation, mutationHandler],
    ]);

    wrapper = mountExtended(McpRegistryApp, {
      apolloProvider,
      provide,
      stubs: { GlTruncate },
    });
  };

  const findRows = () => wrapper.findAllByTestId('mcp-server-row');
  const findStatuses = () => wrapper.findAllByTestId('mcp-server-status');
  const findToggleButtons = () => wrapper.findAllComponentsByTestId('mcp-server-toggle-block');
  const findToggleAt = (i) => findToggleButtons().at(i);
  const findMutationError = () => wrapper.findByTestId('mcp-mutation-error');
  const findPagination = () => wrapper.findComponent(GlKeysetPagination);

  describe('when loading', () => {
    beforeEach(() => {
      createComponent({ queryHandlerImpl: jest.fn(() => new Promise(() => {})) });
    });

    it('shows the loading icon', () => {
      expect(wrapper.findComponent(GlLoadingIcon).exists()).toBe(true);
    });

    it('requests the first page scoped to the group', () => {
      expect(queryHandler).toHaveBeenCalledWith(
        expect.objectContaining({ groupFullPath: GROUP_FULL_PATH, first: 20 }),
      );
    });
  });

  describe('when data is loaded', () => {
    beforeEach(async () => {
      createComponent();
      await waitForPromises();
    });

    it('renders a row per server', () => {
      expect(findRows()).toHaveLength(3);
    });

    it('renders a static External type badge for every server', () => {
      const types = wrapper.findAllByTestId('mcp-server-type');
      expect(types).toHaveLength(3);
      expect(types.at(0).text()).toBe('External');
    });

    it('renders the status per server', () => {
      expect(findStatuses().at(0).text()).toBe('Active');
      expect(findStatuses().at(1).text()).toBe('Blocked');
      expect(findStatuses().at(2).text()).toBe('Blocked');
    });

    it('shows a Block action for active servers and Allow for blocked servers', () => {
      // rows 0 (active) and 1 (blocked) have a toggle; row 2 (inherited) does not
      expect(findToggleButtons()).toHaveLength(2);
      expect(findToggleAt(0).text()).toBe('Block');
      expect(findToggleAt(1).text()).toBe('Allow');
    });

    it('disables the action with a tooltip for ancestor-blocked servers', () => {
      const inherited = wrapper.findByTestId('mcp-server-inherited');
      expect(inherited.exists()).toBe(true);
      expect(inherited.findComponent(GlButton).props('disabled')).toBe(true);
    });

    it('renders the connection URL as a link', () => {
      expect(wrapper.findAllComponents(GlLink).at(0).attributes('href')).toBe(
        'https://figma.mcp.io',
      );
    });

    it('does not render an unsafe (non-http) URL as a live href', async () => {
      createComponent({
        queryHandlerImpl: jest.fn().mockResolvedValue(
          mockQueryResponse({
            nodes: [
              // A deliberately unsafe scheme, to verify the href guard strips it.
              // eslint-disable-next-line no-script-url
              { ...server({ id: 9, name: 'evil' }), url: 'javascript:alert(document.cookie)' },
            ],
            pageInfo: mockPageInfo,
            __typename: 'AiCatalogMcpServerConnection',
          }),
        ),
      });
      await waitForPromises();

      const href = wrapper.findByTestId('mcp-server-url').attributes('href') ?? '';
      expect(href).not.toContain('javascript');
    });

    it('renders a description only for servers that have one', () => {
      expect(wrapper.findAllByTestId('mcp-server-description')).toHaveLength(2);
    });
  });

  describe('blocking a server', () => {
    beforeEach(async () => {
      createComponent();
      await waitForPromises();
    });

    it('fires the mutation with blocked: true for an active server', async () => {
      findToggleAt(0).vm.$emit('click');
      await waitForPromises();

      expect(mutationHandler).toHaveBeenCalledWith({
        id: 'gid://gitlab/Ai::Catalog::McpServer/1',
        groupFullPath: GROUP_FULL_PATH,
        projectFullPath: null,
        blocked: true,
      });
    });

    it('fires the mutation with blocked: false for a blocked server', async () => {
      findToggleAt(1).vm.$emit('click');
      await waitForPromises();

      expect(mutationHandler).toHaveBeenCalledWith(
        expect.objectContaining({ id: 'gid://gitlab/Ai::Catalog::McpServer/2', blocked: false }),
      );
    });

    it('shows an error alert when the mutation returns errors', async () => {
      createComponent({
        mutationHandlerImpl: jest.fn().mockResolvedValue(mockMutationResponse('ACTIVE', ['boom'])),
      });
      await waitForPromises();

      findToggleAt(0).vm.$emit('click');
      await waitForPromises();

      expect(findMutationError().exists()).toBe(true);
    });

    it('shows an error alert when the mutation rejects', async () => {
      createComponent({ mutationHandlerImpl: jest.fn().mockRejectedValue(new Error('network')) });
      await waitForPromises();

      findToggleAt(0).vm.$emit('click');
      await waitForPromises();

      expect(findMutationError().exists()).toBe(true);
    });
  });

  describe('pagination', () => {
    beforeEach(async () => {
      createComponent();
      await waitForPromises();
    });

    it('fetches the next page preserving the group path', async () => {
      findPagination().vm.$emit('next', mockPageInfo.endCursor);
      await waitForPromises();

      expect(queryHandler).toHaveBeenLastCalledWith(
        expect.objectContaining({ after: mockPageInfo.endCursor, groupFullPath: GROUP_FULL_PATH }),
      );
    });
  });

  describe('empty and error states', () => {
    it('renders the empty message', async () => {
      createComponent({
        queryHandlerImpl: jest.fn().mockResolvedValue(
          mockQueryResponse({
            nodes: [],
            pageInfo: { hasNextPage: false, hasPreviousPage: false, __typename: 'PageInfo' },
            __typename: 'AiCatalogMcpServerConnection',
          }),
        ),
      });
      await waitForPromises();

      expect(wrapper.findByTestId('mcp-servers-empty').text()).toBe('No MCP servers found.');
    });

    it('renders an error alert when the query fails', async () => {
      createComponent({ queryHandlerImpl: jest.fn().mockRejectedValue(new Error('boom')) });
      await waitForPromises();

      expect(wrapper.findComponent(GlAlert).text()).toBe('Failed to load MCP servers.');
    });
  });

  describe('badge variants', () => {
    beforeEach(async () => {
      createComponent();
      await waitForPromises();
    });

    it('uses success variant for active and danger for blocked', () => {
      const statusBadges = findStatuses();
      const variantOf = (testidIndex) =>
        wrapper
          .findAllComponents(GlBadge)
          .wrappers.find((w) => w.element === statusBadges.at(testidIndex).element);
      expect(variantOf(0).props('variant')).toBe('success');
      expect(variantOf(1).props('variant')).toBe('danger');
    });
  });

  describe('when scoped to a project', () => {
    beforeEach(async () => {
      createComponent({
        provide: { groupFullPath: GROUP_FULL_PATH, projectFullPath: PROJECT_FULL_PATH },
      });
      await waitForPromises();
    });

    it('queries block status scoped to the project, not the group', () => {
      expect(queryHandler).toHaveBeenCalledWith(
        expect.objectContaining({ projectFullPath: PROJECT_FULL_PATH, groupFullPath: null }),
      );
    });

    it('fires the mutation scoped to the project', async () => {
      findToggleAt(0).vm.$emit('click');
      await waitForPromises();

      expect(mutationHandler).toHaveBeenCalledWith({
        id: 'gid://gitlab/Ai::Catalog::McpServer/1',
        groupFullPath: null,
        projectFullPath: PROJECT_FULL_PATH,
        blocked: true,
      });
    });
  });
});
