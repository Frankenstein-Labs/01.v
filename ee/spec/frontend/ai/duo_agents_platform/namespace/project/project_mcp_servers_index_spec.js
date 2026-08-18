import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import { createAlert } from '~/alert';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import ProjectMcpServersIndex from 'ee/ai/duo_agents_platform/namespace/project/project_mcp_servers_index.vue';
import AiCatalogMcpServersIndex from 'ee/ai/duo_agents_platform/pages/mcp_servers/ai_catalog_mcp_servers_index.vue';
import projectMcpServersQuery from 'ee/ai/duo_agents_platform/graphql/queries/get_project_mcp_servers.query.graphql';

jest.mock('~/alert');

Vue.use(VueApollo);

describe('ProjectMcpServersIndex', () => {
  let wrapper;
  let mockApollo;

  const mockProjectId = 7;

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
        nodes: [],
        pageInfo: { __typename: 'PageInfo', ...mockPageInfo },
      },
    },
  };

  const mockQueryHandler = jest.fn().mockResolvedValue(mockResponse);

  const createComponent = ({ queryHandler = mockQueryHandler } = {}) => {
    mockApollo = createMockApollo([[projectMcpServersQuery, queryHandler]]);

    wrapper = shallowMountExtended(ProjectMcpServersIndex, {
      apolloProvider: mockApollo,
      provide: { projectId: mockProjectId },
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

    it('passes pageInfo to the index', () => {
      expect(findMcpServersIndex().props('pageInfo')).toMatchObject(mockPageInfo);
    });

    it('passes correct empty state description for the project namespace', () => {
      expect(findMcpServersIndex().props('emptyStateDescription')).toBe(
        'MCP servers associated with agents in this project appear here.',
      );
    });

    it('passes the description prop', () => {
      expect(findMcpServersIndex().props('description')).toBe(
        'MCP servers associated with the agents enabled in your project.',
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

  describe('pagination', () => {
    beforeEach(async () => {
      createComponent();
      await waitForPromises();
    });

    it('fetches the query with the projectId variable', () => {
      expect(mockQueryHandler).toHaveBeenCalledWith({
        projectId: `gid://gitlab/Project/${mockProjectId}`,
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
        projectId: `gid://gitlab/Project/${mockProjectId}`,
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
        projectId: `gid://gitlab/Project/${mockProjectId}`,
        after: null,
        before: mockPageInfo.startCursor,
        first: null,
        last: 20,
      });
    });
  });
});
