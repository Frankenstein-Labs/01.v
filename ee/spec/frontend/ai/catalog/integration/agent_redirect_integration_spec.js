import waitForPromises from 'helpers/wait_for_promises';
import { SkipReason, itSkipVue3 } from 'helpers/vue3_conditional';
import { AI_CATALOG_TYPE_AGENT } from 'ee/ai/catalog/constants';
import AiCatalogItemNew from 'ee/ai/catalog/pages/ai_catalog_item_new.vue';
import AiCatalogItemEdit from 'ee/ai/catalog/pages/ai_catalog_item_edit.vue';
import AiCatalogItemDuplicate from 'ee/ai/catalog/pages/ai_catalog_item_duplicate.vue';
import aiCatalogBuiltInToolsQuery from 'ee/ai/catalog/graphql/queries/ai_catalog_built_in_tools.query.graphql';
import aiCatalogMcpServersQuery from 'ee/ai/catalog/graphql/queries/ai_catalog_mcp_servers.query.graphql';
import { mockVersionProp, mockToolsQueryResponse, mockMcpServersQueryResponse } from '../mock_data';
import { createIntegrationWrapper, PROJECT_PROVIDE, ROUTE_PRESETS } from './helpers';
import { createAgentWithPermissions } from './mock_data_factories';

describe('Agent — protected page redirects integration', () => {
  const formQueryHandlers = [
    [aiCatalogBuiltInToolsQuery, jest.fn().mockResolvedValue(mockToolsQueryResponse)],
    [aiCatalogMcpServersQuery, jest.fn().mockResolvedValue(mockMcpServersQueryResponse)],
  ];

  it('user without item admin permission is redirected away from create page', async () => {
    const { router } = createIntegrationWrapper(AiCatalogItemNew, {
      provide: {
        ...PROJECT_PROVIDE,
        glAbilities: { adminAiCatalogItem: false },
      },
      props: {
        itemType: AI_CATALOG_TYPE_AGENT,
      },
      apolloHandlers: [...formQueryHandlers],
      route: ROUTE_PRESETS.agentNew,
    });
    await waitForPromises();

    expect(router.currentRoute.name).toBe('ai-catalog-agents');
  });

  itSkipVue3(
    new SkipReason({
      name: 'user without item admin permission is redirected away from edit page',
      reason: '$route.params.id unavailable in created() with Vue Router 4',
      issue: 'https://gitlab.com/gitlab-org/gitlab/-/issues/593908',
    }),
    async () => {
      const agent = createAgentWithPermissions({ adminAiCatalogItem: false });
      const { router } = createIntegrationWrapper(AiCatalogItemEdit, {
        provide: PROJECT_PROVIDE,
        props: {
          aiCatalogItem: agent,
          version: mockVersionProp,
        },
        apolloHandlers: [...formQueryHandlers],
        route: ROUTE_PRESETS.agentEdit,
      });
      await waitForPromises();

      // eslint-disable-next-line jest/no-standalone-expect
      expect(router.currentRoute.name).toBe('ai-catalog-agents-show');
    },
  );

  itSkipVue3(
    new SkipReason({
      name: 'user without item admin permission is redirected away from duplicate page',
      reason: '$route.params.id unavailable in created() with Vue Router 4',
      issue: 'https://gitlab.com/gitlab-org/gitlab/-/issues/593908',
    }),
    async () => {
      const agent = createAgentWithPermissions({ adminAiCatalogItem: false });
      const { router } = createIntegrationWrapper(AiCatalogItemDuplicate, {
        provide: {
          ...PROJECT_PROVIDE,
          glAbilities: { adminAiCatalogItem: false },
          glFeatures: {},
        },
        props: { aiCatalogItem: agent },
        apolloHandlers: [...formQueryHandlers],
        route: ROUTE_PRESETS.agentDuplicate,
      });
      await waitForPromises();

      // eslint-disable-next-line jest/no-standalone-expect
      expect(router.currentRoute.name).toBe('ai-catalog-agents-show');
    },
  );
});
