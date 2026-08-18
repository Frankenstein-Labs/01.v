import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { GlEmptyState, GlLoadingIcon } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import AiCatalogMcpServer from 'ee/ai/catalog/pages/ai_catalog_mcp_server.vue';
import aiCatalogMcpServerQuery from 'ee/ai/catalog/graphql/queries/ai_catalog_mcp_server.query.graphql';
import { mockMcpServer } from '../mock_data';

jest.mock('~/sentry/sentry_browser_wrapper');

Vue.use(VueApollo);

describe('AiCatalogMcpServer', () => {
  let wrapper;
  let mockApollo;

  const mockMcpServerQueryHandler = jest
    .fn()
    .mockResolvedValue({ data: { aiCatalogMcpServer: mockMcpServer } });

  const routeParams = { id: '1' };

  const createComponent = () => {
    mockApollo = createMockApollo([[aiCatalogMcpServerQuery, mockMcpServerQueryHandler]]);

    wrapper = shallowMountExtended(AiCatalogMcpServer, {
      apolloProvider: mockApollo,
      mocks: {
        $route: { params: routeParams },
      },
      stubs: {
        RouterView: true,
      },
    });
  };

  const findLoadingIcon = () => wrapper.findComponent(GlLoadingIcon);
  const findEmptyState = () => wrapper.findComponent(GlEmptyState);
  const findRouterView = () => wrapper.findComponent({ name: 'RouterView' });

  describe('loading state', () => {
    beforeEach(() => {
      createComponent();
    });

    it('shows loading icon while data is being fetched', () => {
      expect(findLoadingIcon().exists()).toBe(true);
    });

    it('does not render router-view while loading', () => {
      expect(findRouterView().exists()).toBe(false);
    });
  });

  describe('when data is loaded', () => {
    beforeEach(async () => {
      createComponent();
      await waitForPromises();
    });

    it('hides loading icon', () => {
      expect(findLoadingIcon().exists()).toBe(false);
    });

    it('renders router-view with mcp server prop', () => {
      expect(findRouterView().exists()).toBe(true);
      expect(findRouterView().attributes('ai-catalog-mcp-server')).toBeDefined();
    });
  });

  describe('when MCP server is not found', () => {
    beforeEach(async () => {
      mockMcpServerQueryHandler.mockResolvedValue({ data: { aiCatalogMcpServer: null } });
      createComponent();
      await waitForPromises();
    });

    it('shows empty state', () => {
      expect(findEmptyState().exists()).toBe(true);
      expect(findEmptyState().props('title')).toBe('MCP server not found.');
    });

    it('does not render router-view', () => {
      expect(findRouterView().exists()).toBe(false);
    });
  });

  describe('when query fails', () => {
    beforeEach(async () => {
      mockMcpServerQueryHandler.mockRejectedValue(new Error('Network error'));
      createComponent();
      await waitForPromises();
    });

    it('captures exception in Sentry', () => {
      expect(Sentry.captureException).toHaveBeenCalledWith(expect.any(Error));
    });
  });
});
