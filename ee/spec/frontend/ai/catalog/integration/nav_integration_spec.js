import Vue from 'vue';
import waitForPromises from 'helpers/wait_for_promises';
import AiCatalogNavTabs from 'ee/ai/catalog/components/ai_catalog_nav_tabs.vue';
import AiCatalogNavActions from 'ee/ai/catalog/components/ai_catalog_nav_actions.vue';
import {
  createIntegrationWrapper,
  createMockRouter,
  EXPLORE_PROVIDE,
  ROUTE_PRESETS,
} from './helpers';

jest.mock('~/lib/utils/common_utils', () => ({
  ...jest.requireActual('~/lib/utils/common_utils'),
  // isLoggedIn() evaluates Boolean(window.gon?.current_user_id), which is undefined in jsdom
  isLoggedIn: jest.fn().mockReturnValue(true),
}));

// Each GlTab registers itself with the parent GlTabs after mount,
// triggering a deferred re-render of the nav buttons
// Awaiting nextTick so the DOM reflects the updated state
const mountNavTabs = async ({ glAbilities = {} } = {}) => {
  const result = createIntegrationWrapper(AiCatalogNavTabs, {
    provide: { ...EXPLORE_PROVIDE, glAbilities },
    route: ROUTE_PRESETS.agentList,
  });
  await Vue.nextTick();
  return result;
};

const tabTitles = (wrapper) => wrapper.findAll('[role="tab"]').wrappers.map((tab) => tab.text());

const mountAtRoute = async (preset, { canAdmin = false, glAbilities = {} } = {}) => {
  // Pre-navigate before mounting so $route.name is set when the component mounts
  // Vue Router 4 (Vue 3) navigation is async
  // Awaiting ensures params are populated at mount time
  const router = createMockRouter(preset);
  await waitForPromises();
  return createIntegrationWrapper(AiCatalogNavActions, {
    provide: { ...EXPLORE_PROVIDE, glAbilities },
    props: { canAdmin },
    router,
  });
};

describe('Across all routes, any user with catalog access', () => {
  it('can see the Agents tab without additional ability checks', async () => {
    const { wrapper } = await mountNavTabs();

    expect(tabTitles(wrapper)).toContain('Agents');
  });
});

describe('On the agents route', () => {
  describe('a user with canAdmin permissions', () => {
    it('can see the "New agent" button', async () => {
      const { wrapper } = await mountAtRoute(ROUTE_PRESETS.agentList, {
        canAdmin: true,
        glAbilities: { readAiCatalog: true },
      });

      expect(wrapper.findByText('New agent').exists()).toBe(true);
    });
  });

  describe('a user without canAdmin permissions', () => {
    it('cannot see the "New agent" button', async () => {
      const { wrapper } = await mountAtRoute(ROUTE_PRESETS.agentList, { canAdmin: false });

      expect(wrapper.findByText('New agent').exists()).toBe(false);
    });
  });
});

describe('On the flows route', () => {
  describe('a user with canAdmin permissions', () => {
    it('can see the "New flow" button', async () => {
      const { wrapper } = await mountAtRoute(ROUTE_PRESETS.flowList, {
        canAdmin: true,
        glAbilities: { readAiCatalog: true },
      });

      expect(wrapper.findByText('New flow').exists()).toBe(true);
    });
  });

  describe('a user without canAdmin permissions', () => {
    it('cannot see the "New flow" button', async () => {
      const { wrapper } = await mountAtRoute(ROUTE_PRESETS.flowList, { canAdmin: false });

      expect(wrapper.findByText('New flow').exists()).toBe(false);
    });
  });
});

describe('On the MCP servers route', () => {
  describe('a user with the readAiCatalogMcpServer ability', () => {
    it('can see the MCP tab', async () => {
      const { wrapper } = await mountNavTabs({ glAbilities: { readAiCatalogMcpServer: true } });

      expect(tabTitles(wrapper)).toContain('MCP');
    });
  });

  describe('a user without the readAiCatalogMcpServer ability', () => {
    it('cannot see the MCP tab', async () => {
      const { wrapper } = await mountNavTabs();

      expect(tabTitles(wrapper)).not.toContain('MCP');
    });
  });

  describe('a user with canAdmin permissions and the createAiCatalogMcpServer ability', () => {
    it('can see the "New MCP server" button', async () => {
      const { wrapper } = await mountAtRoute(ROUTE_PRESETS.mcpServerList, {
        canAdmin: true,
        glAbilities: { readAiCatalog: true, createAiCatalogMcpServer: true },
      });

      expect(wrapper.findByText('New MCP server').exists()).toBe(true);
    });
  });

  describe('a user with canAdmin permissions but without the createAiCatalogMcpServer ability', () => {
    it('cannot see the "New MCP server" button', async () => {
      const { wrapper } = await mountAtRoute(ROUTE_PRESETS.mcpServerList, {
        canAdmin: true,
        glAbilities: {},
      });

      expect(wrapper.findByText('New MCP server').exists()).toBe(false);
    });
  });
});
