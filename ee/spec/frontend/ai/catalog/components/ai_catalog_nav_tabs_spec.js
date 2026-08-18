import { GlTab, GlTabs } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';

import AiCatalogNavTabs from 'ee/ai/catalog/components/ai_catalog_nav_tabs.vue';
import {
  AI_CATALOG_AGENTS_ROUTE,
  AI_CATALOG_FLOWS_ROUTE,
  AI_CATALOG_MCP_SERVERS_ROUTE,
} from 'ee/ai/catalog/router/constants';

describe('AiCatalogNavTabs', () => {
  let wrapper;

  const mockRouter = {
    push: jest.fn(),
  };

  const createComponent = ({
    routeName = AI_CATALOG_AGENTS_ROUTE,
    routeQuery = {},
    readAiCatalogMcpServer = false,
  } = {}) => {
    wrapper = shallowMountExtended(AiCatalogNavTabs, {
      mocks: {
        $route: {
          name: routeName,
          query: routeQuery,
        },
        $router: mockRouter,
      },
      provide: {
        glAbilities: {
          readAiCatalogMcpServer,
        },
      },
    });
  };

  const findTabs = () => wrapper.findComponent(GlTabs);
  const findAllTabs = () => wrapper.findAllComponents(GlTab);

  describe('template', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders tabs', () => {
      expect(findTabs().exists()).toBe(true);
    });

    it('renders the correct number of tabs', () => {
      expect(findAllTabs()).toHaveLength(2);
    });

    it('renders the Agents tab as active', () => {
      const agentsTab = findAllTabs().at(0);

      expect(agentsTab.attributes('title')).toBe('Agents');
      expect(agentsTab.attributes('active')).toBe('true');
    });

    it('renders the Flows tab', () => {
      const flowsTab = findAllTabs().at(1);

      expect(flowsTab.attributes('title')).toBe('Flows');
    });
  });

  describe('when on Flows route', () => {
    beforeEach(() => {
      createComponent({ routeName: AI_CATALOG_FLOWS_ROUTE });
    });

    it('renders the Flows tab as active', () => {
      const flowsTab = findAllTabs().at(1);

      expect(flowsTab.attributes('active')).toBe('true');
    });
  });

  describe('MCP servers tab', () => {
    describe('when user does not have read permission', () => {
      beforeEach(() => {
        createComponent({ readAiCatalogMcpServer: false });
      });

      it('does not render the MCP tab', () => {
        expect(findAllTabs()).toHaveLength(2);
        expect(findAllTabs().at(0).attributes('title')).toBe('Agents');
        expect(findAllTabs().at(1).attributes('title')).toBe('Flows');
      });
    });

    describe('when user has read permission', () => {
      beforeEach(() => {
        createComponent({ readAiCatalogMcpServer: true });
      });

      it('renders the MCP tab', () => {
        expect(findAllTabs()).toHaveLength(3);
        expect(findAllTabs().at(2).attributes('title')).toBe('MCP');
      });
    });

    describe('when on MCP servers route', () => {
      beforeEach(() => {
        createComponent({ routeName: AI_CATALOG_MCP_SERVERS_ROUTE, readAiCatalogMcpServer: true });
      });

      it('renders the MCP tab as active', () => {
        const mcpTab = findAllTabs().at(2);

        expect(mcpTab.attributes('active')).toBe('true');
      });
    });
  });

  describe('navigation', () => {
    it('navigates to the correct route when tab is clicked', () => {
      createComponent();

      const agentsTab = findAllTabs().at(1);

      agentsTab.vm.$emit('click');

      expect(mockRouter.push).toHaveBeenCalledWith({ name: AI_CATALOG_FLOWS_ROUTE, query: {} });
    });

    it('preserves query params when navigating between tabs', () => {
      createComponent({ routeName: AI_CATALOG_AGENTS_ROUTE, routeQuery: { search: 'test' } });

      const flowsTab = findAllTabs().at(1);

      flowsTab.vm.$emit('click');

      expect(mockRouter.push).toHaveBeenCalledWith({
        name: AI_CATALOG_FLOWS_ROUTE,
        query: { search: 'test' },
      });
    });

    it('does not navigate if already on the same route', () => {
      createComponent({ routeName: AI_CATALOG_AGENTS_ROUTE });

      const agentsTab = findAllTabs().at(0);

      agentsTab.vm.$emit('click');

      expect(mockRouter.push).not.toHaveBeenCalled();
    });
  });
});
