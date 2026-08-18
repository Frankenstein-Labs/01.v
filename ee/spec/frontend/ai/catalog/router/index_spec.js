import { createRouter } from 'ee/ai/catalog/router';
import {
  AI_CATALOG_AGENTS_ROUTE,
  AI_CATALOG_AGENTS_SHOW_ROUTE,
  AI_CATALOG_AGENTS_EDIT_ROUTE,
  AI_CATALOG_AGENTS_NEW_ROUTE,
  AI_CATALOG_AGENTS_DUPLICATE_ROUTE,
  AI_CATALOG_FOUNDATIONAL_AGENTS_SHOW_ROUTE,
  AI_CATALOG_FLOWS_ROUTE,
  AI_CATALOG_FLOWS_SHOW_ROUTE,
  AI_CATALOG_FLOWS_EDIT_ROUTE,
  AI_CATALOG_FLOWS_NEW_ROUTE,
  AI_CATALOG_FLOWS_DUPLICATE_ROUTE,
  AI_CATALOG_MCP_SERVERS_ROUTE,
  AI_CATALOG_MCP_SERVERS_SHOW_ROUTE,
  AI_CATALOG_MCP_SERVERS_NEW_ROUTE,
  AI_CATALOG_MCP_SERVERS_EDIT_ROUTE,
} from 'ee/ai/catalog/router/constants';
import { isLoggedIn } from '~/lib/utils/common_utils';

jest.mock('~/lib/utils/common_utils');

describe('AI Catalog Router', () => {
  let router;

  const agentId = 1;
  const flowId = 1;

  beforeEach(() => {
    isLoggedIn.mockReturnValue(true);
    router = createRouter();

    // this is needed to disable the warning thrown for incorrect path
    // eslint-disable-next-line no-console
    console.warn = jest.fn();
  });

  describe('Agent child routes', () => {
    it.each`
      testName              | path                              | expectedRouteName
      ${'agents index'}     | ${'/agents'}                      | ${AI_CATALOG_AGENTS_ROUTE}
      ${'agents new'}       | ${'/agents/new'}                  | ${AI_CATALOG_AGENTS_NEW_ROUTE}
      ${'agents show'}      | ${`/agents/${agentId}`}           | ${AI_CATALOG_AGENTS_SHOW_ROUTE}
      ${'agents edit'}      | ${`/agents/${agentId}/edit`}      | ${AI_CATALOG_AGENTS_EDIT_ROUTE}
      ${'agents duplicate'} | ${`/agents/${agentId}/duplicate`} | ${AI_CATALOG_AGENTS_DUPLICATE_ROUTE}
    `('renders $testName child route', async ({ path, expectedRouteName }) => {
      await router.push(path);

      expect(router.currentRoute.name).toBe(expectedRouteName);
    });
  });

  describe('Flows child routes', () => {
    it.each`
      testName             | path                            | expectedRouteName
      ${'flows index'}     | ${'/flows'}                     | ${AI_CATALOG_FLOWS_ROUTE}
      ${'flows show'}      | ${`/flows/${agentId}`}          | ${AI_CATALOG_FLOWS_SHOW_ROUTE}
      ${'flows new'}       | ${'/flows/new'}                 | ${AI_CATALOG_FLOWS_NEW_ROUTE}
      ${'flows edit'}      | ${`/flows/${flowId}/edit`}      | ${AI_CATALOG_FLOWS_EDIT_ROUTE}
      ${'flows duplicate'} | ${`/flows/${flowId}/duplicate`} | ${AI_CATALOG_FLOWS_DUPLICATE_ROUTE}
    `('renders $testName child route', async ({ path, expectedRouteName }) => {
      await router.push(path);

      expect(router.currentRoute.name).toBe(expectedRouteName);
    });
  });

  describe('When aiCatalogSyntheticFoundationalItems feature flag is on', () => {
    beforeEach(() => {
      gon.features = {
        aiCatalogSyntheticFoundationalItems: true,
      };
      router = createRouter();
    });

    it('renders foundational agents show route', async () => {
      await router.push('/foundational_agents/gitlab-duo-chat');

      expect(router.currentRoute.name).toBe(AI_CATALOG_FOUNDATIONAL_AGENTS_SHOW_ROUTE);
      expect(router.currentRoute.params.reference).toBe('gitlab-duo-chat');
    });

    it('redirects bare foundational agents path to agents route', async () => {
      await router.push('/flows');

      expect(router.currentRoute.name).toBe(AI_CATALOG_FLOWS_ROUTE);

      await router.push('/foundational_agents');

      expect(router.currentRoute.name).toBe(AI_CATALOG_AGENTS_ROUTE);
    });
  });

  describe('When aiCatalogSyntheticFoundationalItems feature flag is off', () => {
    beforeEach(() => {
      gon.features = {
        aiCatalogSyntheticFoundationalItems: false,
      };
      router = createRouter();
    });

    it('redirects foundational agents path to agents route', async () => {
      await router.push('/foundational_agents/gitlab-duo-chat');

      expect(router.currentRoute.name).toBe(AI_CATALOG_AGENTS_ROUTE);
    });

    it('redirects bare foundational agents path to agents route', async () => {
      await router.push('/flows');

      expect(router.currentRoute.name).toBe(AI_CATALOG_FLOWS_ROUTE);

      await router.push('/foundational_agents');

      expect(router.currentRoute.name).toBe(AI_CATALOG_AGENTS_ROUTE);
    });
  });

  describe('Non-numeric ID routes', () => {
    it.each`
      type        | path
      ${'agents'} | ${'/agents/abc'}
      ${'flows'}  | ${'/flows/abc'}
    `('redirects to index for non-numeric $type id', async ({ path }) => {
      await router.push(path);

      expect(router.currentRoute.path).toMatch(/^\/agents\/?$/);
    });
  });

  describe('When user is not logged in', () => {
    beforeEach(() => {
      gon.abilities = {
        readAiCatalogMcpServer: true,
      };
      router = createRouter();
      isLoggedIn.mockReturnValue(false);
    });

    it.each`
      testName              | path
      ${'agents new'}       | ${'/agents/new'}
      ${'agents edit'}      | ${`/agents/${agentId}/edit`}
      ${'agents duplicate'} | ${`/agents/${agentId}/duplicate`}
      ${'flows new'}        | ${'/flows/new'}
      ${'flows edit'}       | ${`/flows/${flowId}/edit`}
      ${'flows duplicate'}  | ${`/flows/${flowId}/duplicate`}
    `('redirects $testName route to index when not logged in', async ({ path }) => {
      try {
        await router.push(path);
      } catch (error) {
        // intentionally blank
        //
        // * in Vue.js 2 this will trigger "redundant navigation" error and will be caught here
      }

      expect(router.currentRoute.path).toMatch(/^\/agents\/?$/);
    });

    it.each`
      testName               | path              | expectedRouteName
      ${'index route'}       | ${''}             | ${AI_CATALOG_AGENTS_ROUTE}
      ${'agents index'}      | ${`/agents`}      | ${AI_CATALOG_AGENTS_ROUTE}
      ${'flows index'}       | ${`/flows`}       | ${AI_CATALOG_FLOWS_ROUTE}
      ${'mcp-servers index'} | ${`/mcp-servers`} | ${AI_CATALOG_MCP_SERVERS_ROUTE}
    `('lets the user enter the page', async ({ path, expectedRouteName }) => {
      await router.push(path);

      expect(router.currentRoute.name).toBe(expectedRouteName);
    });
  });

  describe('When user has read MCP server permission', () => {
    const mcpServerId = 1;

    beforeEach(() => {
      gon.abilities = {
        readAiCatalogMcpServer: true,
      };
      router = createRouter();
    });

    it.each`
      testName               | path                             | expectedRouteName
      ${'mcp-servers index'} | ${'/mcp-servers'}                | ${AI_CATALOG_MCP_SERVERS_ROUTE}
      ${'mcp-servers show'}  | ${`/mcp-servers/${mcpServerId}`} | ${AI_CATALOG_MCP_SERVERS_SHOW_ROUTE}
    `('renders $testName child route', async ({ path, expectedRouteName }) => {
      await router.push(path);

      expect(router.currentRoute.name).toBe(expectedRouteName);
    });

    describe('and user has create MCP server permission', () => {
      beforeEach(() => {
        gon.abilities = {
          readAiCatalogMcpServer: true,
          createAiCatalogMcpServer: true,
        };
        router = createRouter();
      });

      it('renders mcp-servers new child route', async () => {
        await router.push('/mcp-servers/new');

        expect(router.currentRoute.name).toBe(AI_CATALOG_MCP_SERVERS_NEW_ROUTE);
      });
    });

    describe('and user does not have create MCP server permission', () => {
      beforeEach(() => {
        gon.abilities = {
          readAiCatalogMcpServer: true,
          createAiCatalogMcpServer: false,
        };
        router = createRouter();
      });

      it('redirects mcp-servers/new to mcp-servers index', async () => {
        try {
          await router.push('/mcp-servers/new');
        } catch (error) {
          // intentionally blank
          //
          // * in Vue.js 2 this will trigger "redundant navigation" error and will be caught here
        }

        expect(router.currentRoute.name).toBe(AI_CATALOG_MCP_SERVERS_ROUTE);
      });
    });

    describe('and user has update MCP server permission', () => {
      beforeEach(() => {
        gon.abilities = {
          readAiCatalogMcpServer: true,
          updateAiCatalogMcpServer: true,
        };
        router = createRouter();
      });

      it('renders mcp-servers edit child route', async () => {
        await router.push(`/mcp-servers/${mcpServerId}/edit`);

        expect(router.currentRoute.name).toBe(AI_CATALOG_MCP_SERVERS_EDIT_ROUTE);
      });
    });

    describe('and user does not have update MCP server permission', () => {
      beforeEach(() => {
        gon.abilities = {
          readAiCatalogMcpServer: true,
          updateAiCatalogMcpServer: false,
        };
        router = createRouter();
      });

      it('redirects mcp-servers/:id/edit to mcp-servers index', async () => {
        try {
          await router.push(`/mcp-servers/${mcpServerId}/edit`);
        } catch (error) {
          // intentionally blank
          //
          // * in Vue.js 2 this will trigger "redundant navigation" error and will be caught here
        }

        expect(router.currentRoute.name).toBe(AI_CATALOG_MCP_SERVERS_ROUTE);
      });
    });
  });

  describe('When user does not have read MCP server permission', () => {
    beforeEach(() => {
      gon.abilities = {
        readAiCatalogMcpServer: false,
      };
      router = createRouter();
    });

    it.each`
      testName               | path                  | expectedRouteName
      ${'mcp-servers index'} | ${'/mcp-servers'}     | ${AI_CATALOG_AGENTS_ROUTE}
      ${'mcp-servers show'}  | ${'/mcp-servers/1'}   | ${AI_CATALOG_AGENTS_ROUTE}
      ${'mcp-servers new'}   | ${'/mcp-servers/new'} | ${AI_CATALOG_AGENTS_ROUTE}
    `('redirects $testName to agents route', async ({ path, expectedRouteName }) => {
      await router.push(path);

      expect(router.currentRoute.name).toBe(expectedRouteName);
    });
  });

  describe('Unknown path fallback', () => {
    it('redirects to index for unknown route', async () => {
      await router.push('/some/unknown/path');

      expect(router.currentRoute.path).toMatch(/^\/agents\/?$/);
    });
  });

  describe('afterEach hook - page titles', () => {
    const originalTitle = 'AI Catalog · GitLab';

    beforeEach(() => {
      document.title = originalTitle;
      router = createRouter();
    });

    it('sets document title for agents route', async () => {
      await router.push('/agents');

      expect(document.title).toBe('Agents · AI Catalog · GitLab');
    });

    it('sets document title for new agent route', async () => {
      await router.push('/agents/new');

      expect(document.title).toBe('New agent · AI Catalog · GitLab');
    });

    it('sets document title for flows route', async () => {
      await router.push('/flows');

      expect(document.title).toBe('Flows · AI Catalog · GitLab');
    });

    it('sets document title for new flow route', async () => {
      await router.push('/flows/new');

      expect(document.title).toBe('New flow · AI Catalog · GitLab');
    });

    it('sets document title for MCP servers route', async () => {
      gon.abilities = {
        readAiCatalogMcpServer: true,
      };
      document.title = originalTitle;
      router = createRouter();

      await router.push('/mcp-servers');

      expect(document.title).toBe('MCP · AI Catalog · GitLab');
    });

    it('sets document title for new MCP server route', async () => {
      gon.abilities = {
        readAiCatalogMcpServer: true,
        createAiCatalogMcpServer: true,
      };
      document.title = originalTitle;
      router = createRouter();

      await router.push('/mcp-servers/new');

      expect(document.title).toBe('New MCP server · AI Catalog · GitLab');
    });

    it('does not set document title for routes without meta.title', async () => {
      await router.push('/agents');
      const titleAfterAgents = document.title;

      // Navigate to a route without meta.title (item page)
      await router.push(`/agents/${agentId}`);

      expect(document.title).toBe(titleAfterAgents);
    });

    it('does not set document title for agent routes with useId meta', async () => {
      await router.push('/agents');
      const titleAfterAgents = document.title;

      await router.push(`/agents/${agentId}`);

      expect(document.title).toBe(titleAfterAgents);
    });

    it('does not set document title for flow routes with useId meta', async () => {
      await router.push('/flows');
      const titleAfterFlows = document.title;

      await router.push(`/flows/${flowId}`);

      expect(document.title).toBe(titleAfterFlows);
    });
  });
});
