import Vue from 'vue';
import VueRouter from 'vue-router';
import { s__ } from '~/locale';
import {
  AI_CATALOG_AGENTS_ROUTE,
  AI_CATALOG_AGENTS_SHOW_ROUTE,
  AI_CATALOG_AGENTS_NEW_ROUTE,
  AI_CATALOG_AGENTS_EDIT_ROUTE,
  AI_CATALOG_AGENTS_DUPLICATE_ROUTE,
  AI_CATALOG_FOUNDATIONAL_AGENTS_SHOW_ROUTE,
  AI_CATALOG_FLOWS_ROUTE,
  AI_CATALOG_FLOWS_SHOW_ROUTE,
  AI_CATALOG_FLOWS_NEW_ROUTE,
  AI_CATALOG_FLOWS_EDIT_ROUTE,
  AI_CATALOG_FLOWS_DUPLICATE_ROUTE,
} from 'ee/ai/catalog/router/constants';
import {
  AI_CATALOG_TYPE_AGENT,
  AI_CATALOG_TYPE_FLOW,
  AI_CATALOG_TYPE_FOUNDATIONAL_AGENT,
} from 'ee/ai/catalog/constants';
import AiCatalogItem from 'ee/ai/catalog/pages/ai_catalog_item.vue';
import AiCatalogItemNew from 'ee/ai/catalog/pages/ai_catalog_item_new.vue';
import AiCatalogItemDuplicate from 'ee/ai/catalog/pages/ai_catalog_item_duplicate.vue';
import AiCatalogItemShow from 'ee/ai/catalog/pages/ai_catalog_item_show.vue';
import AiCatalogItemEdit from 'ee/ai/catalog/pages/ai_catalog_item_edit.vue';
import AiCatalogMcpServer from 'ee/ai/catalog/pages/ai_catalog_mcp_server.vue';
import AiCatalogMcpServersShow from 'ee/ai/catalog/pages/ai_catalog_mcp_servers_show.vue';
import NestedRouteApp from '~/vue_shared/spa/components/router_view.vue';
import AgentsPlatformShow from '../pages/show/duo_agents_platform_show.vue';
import FlowTriggersIndex from '../pages/flow_triggers/index/flow_triggers_index.vue';
import FlowTriggersNew from '../pages/flow_triggers/flow_triggers_new.vue';
import FlowTriggersEdit from '../pages/flow_triggers/flow_triggers_edit.vue';
import AiItemsIndex from '../pages/ai_items_index.vue';
import ReadinessDashboard from '../pages/onboarding/readiness_dashboard.vue';
import { AGENT_PLATFORM_PROJECT_PAGE } from '../constants';
import {
  AGENTS_PLATFORM_INDEX_ROUTE,
  AGENTS_PLATFORM_SHOW_ROUTE,
  AGENTS_PLATFORM_ONBOARDING_ROUTE,
  FLOW_TRIGGERS_INDEX_ROUTE,
  FLOW_TRIGGERS_NEW_ROUTE,
  FLOW_TRIGGERS_EDIT_ROUTE,
  MCP_SERVERS_INDEX_ROUTE,
  MCP_SERVERS_SHOW_ROUTE,
} from './constants';
import { getNamespaceIndexComponent, getMcpServersIndexComponent, setPreviousRoute } from './utils';

Vue.use(VueRouter);

export const createRouter = (base, namespaceType) => {
  const baseTitle = document.title;
  const isProjectNamespace = namespaceType === AGENT_PLATFORM_PROJECT_PAGE;

  const router = new VueRouter({
    base,
    mode: 'history',
    routes: [
      {
        component: NestedRouteApp,
        path: '/agent-sessions',
        meta: {
          text: s__('DuoAgentsPlatform|Sessions'),
        },
        children: [
          {
            name: AGENTS_PLATFORM_INDEX_ROUTE,
            path: '',
            component: getNamespaceIndexComponent(namespaceType),
            meta: {
              title: s__('DuoAgentsPlatform|Sessions'),
            },
          },
          // Used as hardcoded path in
          // https://gitlab.com/gitlab-org/gitlab/-/blob/e9b59c5de32c6ce4e14665681afbf95cf001c044/ee/app/assets/javascripts/ai/components/duo_workflow_action.vue#L76.
          {
            name: AGENTS_PLATFORM_SHOW_ROUTE,
            path: ':id(\\d+)',
            component: AgentsPlatformShow,
            meta: {
              useId: true,
            },
          },
        ],
      },
      {
        component: NestedRouteApp,
        path: '/triggers',
        meta: {
          text: s__('DuoAgentsPlatform|Triggers'),
        },
        children: [
          {
            name: FLOW_TRIGGERS_INDEX_ROUTE,
            path: '',
            component: FlowTriggersIndex,
            meta: {
              title: s__('DuoAgentsPlatform|Triggers'),
            },
          },
          ...(gon.abilities?.readAiCatalogThirdPartyFlow ||
          gon.abilities?.createAiCatalogThirdPartyFlow ||
          gon.abilities?.readAiCatalogFlow
            ? [
                {
                  name: FLOW_TRIGGERS_NEW_ROUTE,
                  path: 'new',
                  component: FlowTriggersNew,
                  meta: {
                    text: s__('DuoAgentsPlatform|New trigger'),
                  },
                },
              ]
            : []),
          {
            path: ':id(\\d+)/edit',
            component: FlowTriggersEdit,
            name: FLOW_TRIGGERS_EDIT_ROUTE,
            meta: {
              text: s__('DuoAgentsPlatform|Edit trigger'),
              title: s__('DuoAgentsPlatform|Edit trigger'),
            },
          },
          {
            path: ':id/edit',
            redirect: '/triggers',
          },
        ],
      },
      {
        component: NestedRouteApp,
        path: '/agents',
        meta: {
          text: s__('AICatalog|Agents'),
        },
        children: [
          {
            name: AI_CATALOG_AGENTS_ROUTE,
            path: '',
            component: AiItemsIndex,
            meta: {
              title: s__('AICatalog|Agents'),
            },
            props: {
              itemType: AI_CATALOG_TYPE_AGENT,
            },
          },
          ...(isProjectNamespace
            ? [
                {
                  name: AI_CATALOG_AGENTS_NEW_ROUTE,
                  path: 'new',
                  component: AiCatalogItemNew,
                  meta: {
                    text: s__('AICatalog|New agent'),
                    title: s__('AICatalog|New agent'),
                  },
                  props: {
                    itemType: AI_CATALOG_TYPE_AGENT,
                  },
                },
                {
                  path: ':id(\\d+)',
                  component: AiCatalogItem,
                  props: { itemType: AI_CATALOG_TYPE_AGENT },
                  meta: {
                    useId: true,
                    defaultRoute: AI_CATALOG_AGENTS_SHOW_ROUTE,
                  },
                  children: [
                    {
                      name: AI_CATALOG_AGENTS_SHOW_ROUTE,
                      path: '',
                      component: AiCatalogItemShow,
                    },
                    {
                      name: AI_CATALOG_AGENTS_EDIT_ROUTE,
                      path: 'edit',
                      component: AiCatalogItemEdit,
                      meta: {
                        text: s__('AICatalog|Edit agent'),
                      },
                    },
                    {
                      name: AI_CATALOG_AGENTS_DUPLICATE_ROUTE,
                      path: 'duplicate',
                      component: AiCatalogItemDuplicate,
                      meta: {
                        text: s__('AICatalog|Duplicate agent'),
                      },
                    },
                  ],
                },
              ]
            : [
                {
                  path: ':id(\\d+)',
                  component: AiCatalogItem,
                  props: { itemType: AI_CATALOG_TYPE_AGENT },
                  meta: {
                    useId: true,
                  },
                  children: [
                    {
                      name: AI_CATALOG_AGENTS_SHOW_ROUTE,
                      path: '',
                      component: AiCatalogItemShow,
                    },
                  ],
                },
              ]),
          { path: '*', redirect: '/agents' },
        ],
      },
      // FOUNDATIONAL AGENTS
      ...(gon.features?.aiCatalogSyntheticFoundationalItems
        ? [
            {
              component: NestedRouteApp,
              path: '/foundational_agents',
              meta: {
                title: s__('AICatalog|Agents'),
                text: s__('AICatalog|Agents'),
                indexRoute: AI_CATALOG_AGENTS_ROUTE,
              },
              children: [
                {
                  path: '',
                  redirect: { name: AI_CATALOG_AGENTS_ROUTE },
                },
                {
                  path: ':reference',
                  component: AiCatalogItem,
                  props: { itemType: AI_CATALOG_TYPE_FOUNDATIONAL_AGENT },
                  meta: {
                    useId: true,
                    indexRoute: AI_CATALOG_FOUNDATIONAL_AGENTS_SHOW_ROUTE,
                  },
                  children: [
                    {
                      name: AI_CATALOG_FOUNDATIONAL_AGENTS_SHOW_ROUTE,
                      path: '',
                      component: AiCatalogItemShow,
                    },
                  ],
                },
              ],
            },
          ]
        : []),
      {
        component: NestedRouteApp,
        path: '/flows',
        meta: {
          text: s__('AICatalog|Flows'),
        },
        children: [
          {
            name: AI_CATALOG_FLOWS_ROUTE,
            path: '',
            component: AiItemsIndex,
            meta: {
              title: s__('AICatalog|Flows'),
            },
            props: {
              itemType: AI_CATALOG_TYPE_FLOW,
            },
          },
          ...(isProjectNamespace
            ? [
                {
                  name: AI_CATALOG_FLOWS_NEW_ROUTE,
                  path: 'new',
                  component: AiCatalogItemNew,
                  meta: {
                    text: s__('AICatalog|New flow'),
                    title: s__('AICatalog|New flow'),
                  },
                  props: {
                    itemType: AI_CATALOG_TYPE_FLOW,
                  },
                },
                {
                  path: ':id(\\d+)',
                  component: AiCatalogItem,
                  props: { itemType: AI_CATALOG_TYPE_FLOW },
                  meta: {
                    useId: true,
                    defaultRoute: AI_CATALOG_FLOWS_SHOW_ROUTE,
                  },
                  children: [
                    {
                      name: AI_CATALOG_FLOWS_SHOW_ROUTE,
                      path: '',
                      component: AiCatalogItemShow,
                    },
                    {
                      name: AI_CATALOG_FLOWS_EDIT_ROUTE,
                      path: 'edit',
                      component: AiCatalogItemEdit,
                      meta: {
                        text: s__('AICatalog|Edit flow'),
                      },
                    },
                    {
                      name: AI_CATALOG_FLOWS_DUPLICATE_ROUTE,
                      path: 'duplicate',
                      component: AiCatalogItemDuplicate,
                      meta: {
                        text: s__('AICatalog|Duplicate flow'),
                      },
                    },
                  ],
                },
              ]
            : [
                {
                  path: ':id(\\d+)',
                  component: AiCatalogItem,
                  props: { itemType: AI_CATALOG_TYPE_FLOW },
                  meta: {
                    useId: true,
                  },
                  children: [
                    {
                      name: AI_CATALOG_FLOWS_SHOW_ROUTE,
                      path: '',
                      component: AiCatalogItemShow,
                    },
                  ],
                },
              ]),
          { path: '*', redirect: '/flows' },
        ],
      },
      {
        component: NestedRouteApp,
        path: '/mcp-servers',
        meta: {
          text: s__('AICatalog|MCP servers'),
        },
        children: [
          {
            name: MCP_SERVERS_INDEX_ROUTE,
            path: '',
            component: getMcpServersIndexComponent(namespaceType),
          },
          {
            path: ':id(\\d+)',
            component: AiCatalogMcpServer,
            meta: {
              useId: true,
            },
            children: [
              {
                name: MCP_SERVERS_SHOW_ROUTE,
                path: '',
                component: AiCatalogMcpServersShow,
              },
            ],
          },
        ],
      },
      ...(gon.features?.duoAgentOnboarding
        ? [
            {
              component: NestedRouteApp,
              path: '/onboarding',
              meta: { text: s__('DuoAgentsPlatform|Onboarding') },
              children: [
                {
                  name: AGENTS_PLATFORM_ONBOARDING_ROUTE,
                  path: '',
                  component: ReadinessDashboard,
                  meta: {
                    title: s__('DuoAgentsPlatform|Onboarding'),
                  },
                },
              ],
            },
          ]
        : []),
      // /automate route is currently empty, so we can't redirect there
      { path: '*', redirect: '/agent-sessions' },
    ],
  });

  router.beforeEach((_, from, next) => {
    if (from.name) {
      setPreviousRoute(from);
    }
    next();
  });

  router.afterEach((to) => {
    // Agent/flow pages handle their own titles in components to display item name
    const isItemPage = to.matched.some((route) => route.meta?.useId);

    if (!isItemPage && to.meta.title) {
      document.title = `${to.meta.title} · ${baseTitle}`;
    }
  });

  return router;
};
