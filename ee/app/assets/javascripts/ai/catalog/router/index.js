import Vue from 'vue';
import VueRouter from 'vue-router';
import { s__ } from '~/locale';
import { isLoggedIn } from '~/lib/utils/common_utils';
import NestedRouteApp from '~/vue_shared/spa/components/router_view.vue';
import AiCatalogItemNew from '../pages/ai_catalog_item_new.vue';
import AiCatalogItem from '../pages/ai_catalog_item.vue';
import AiCatalogItemDuplicate from '../pages/ai_catalog_item_duplicate.vue';
import AiCatalogItemShow from '../pages/ai_catalog_item_show.vue';
import AiCatalogItemsIndex from '../pages/ai_catalog_items_index.vue';
import AiCatalogItemEdit from '../pages/ai_catalog_item_edit.vue';
import AiCatalogMcpServers from '../pages/ai_catalog_mcp_servers.vue';
import AiCatalogMcpServer from '../pages/ai_catalog_mcp_server.vue';
import AiCatalogMcpServersShow from '../pages/ai_catalog_mcp_servers_show.vue';
import AiCatalogMcpServersNew from '../pages/ai_catalog_mcp_servers_new.vue';
import AiCatalogMcpServersEdit from '../pages/ai_catalog_mcp_servers_edit.vue';
import {
  AI_CATALOG_TYPE_AGENT,
  AI_CATALOG_TYPE_FLOW,
  AI_CATALOG_TYPE_FOUNDATIONAL_AGENT,
} from '../constants';
import {
  AI_CATALOG_INDEX_ROUTE,
  AI_CATALOG_AGENTS_ROUTE,
  AI_CATALOG_AGENTS_SHOW_ROUTE,
  AI_CATALOG_AGENTS_EDIT_ROUTE,
  AI_CATALOG_AGENTS_NEW_ROUTE,
  AI_CATALOG_AGENTS_DUPLICATE_ROUTE,
  AI_CATALOG_FOUNDATIONAL_AGENTS_SHOW_ROUTE,
  AI_CATALOG_FLOWS_ROUTE,
  AI_CATALOG_FLOWS_SHOW_ROUTE,
  AI_CATALOG_FLOWS_NEW_ROUTE,
  AI_CATALOG_FLOWS_EDIT_ROUTE,
  AI_CATALOG_FLOWS_DUPLICATE_ROUTE,
  AI_CATALOG_MCP_SERVERS_ROUTE,
  AI_CATALOG_MCP_SERVERS_SHOW_ROUTE,
  AI_CATALOG_MCP_SERVERS_NEW_ROUTE,
  AI_CATALOG_MCP_SERVERS_EDIT_ROUTE,
} from './constants';

Vue.use(VueRouter);

const requireAuth = (_, __, next) => {
  if (isLoggedIn()) {
    next();
  } else {
    next({ name: AI_CATALOG_INDEX_ROUTE });
  }
};

export const createRouter = (base) => {
  const baseTitle = document.title;

  const router = new VueRouter({
    base,
    mode: 'history',
    routes: [
      {
        name: AI_CATALOG_INDEX_ROUTE,
        path: '/',
        redirect: { name: AI_CATALOG_AGENTS_ROUTE },
      },
      // AGENTS
      {
        component: NestedRouteApp,
        path: '/agents',
        meta: {
          title: s__('AICatalog|Agents'),
          text: s__('AICatalog|Agents'), // Defined on the parent so that all children inherit this as a breadcrumb
          indexRoute: AI_CATALOG_AGENTS_ROUTE, // Used by breadcrumbs to ensure we can identify the index for this tree
        },
        children: [
          {
            name: AI_CATALOG_AGENTS_ROUTE,
            path: '',
            component: AiCatalogItemsIndex,
            props: { itemType: AI_CATALOG_TYPE_AGENT },
            meta: {
              title: s__('AICatalog|Agents'),
            },
          },
          {
            name: AI_CATALOG_AGENTS_NEW_ROUTE,
            path: 'new',
            component: AiCatalogItemNew,
            beforeEnter: requireAuth,
            meta: {
              title: s__('AICatalog|New agent'),
              text: s__('AICatalog|New agent'),
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
              useId: true, // Defined on this parent so that all children inherit the param ID as a breadcrumb
              indexRoute: AI_CATALOG_AGENTS_SHOW_ROUTE,
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
                beforeEnter: requireAuth,
                meta: {
                  text: s__('AICatalog|Edit agent'),
                },
              },
              {
                name: AI_CATALOG_AGENTS_DUPLICATE_ROUTE,
                path: 'duplicate',
                component: AiCatalogItemDuplicate,
                beforeEnter: requireAuth,
                meta: {
                  text: s__('AICatalog|Duplicate agent'),
                },
              },
            ],
          },
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
      // FLOWS
      {
        component: NestedRouteApp,
        path: '/flows',
        meta: {
          title: s__('AICatalog|Flows'),
          text: s__('AICatalog|Flows'),
          indexRoute: AI_CATALOG_FLOWS_ROUTE,
        },
        children: [
          {
            name: AI_CATALOG_FLOWS_ROUTE,
            path: '',
            component: AiCatalogItemsIndex,
            props: { itemType: AI_CATALOG_TYPE_FLOW },
            meta: {
              title: s__('AICatalog|Flows'),
            },
          },
          {
            name: AI_CATALOG_FLOWS_NEW_ROUTE,
            path: 'new',
            component: AiCatalogItemNew,
            beforeEnter: requireAuth,
            meta: {
              title: s__('AICatalog|New flow'),
              text: s__('AICatalog|New flow'),
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
              indexRoute: AI_CATALOG_FLOWS_SHOW_ROUTE,
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
                beforeEnter: requireAuth,
                meta: {
                  text: s__('AICatalog|Edit flow'),
                },
              },
              {
                name: AI_CATALOG_FLOWS_DUPLICATE_ROUTE,
                path: 'duplicate',
                component: AiCatalogItemDuplicate,
                beforeEnter: requireAuth,
                meta: {
                  text: s__('AICatalog|Duplicate flow'),
                },
              },
            ],
          },
        ],
      },
      // MCP SERVERS
      ...(gon.abilities?.readAiCatalogMcpServer
        ? [
            {
              component: NestedRouteApp,
              path: '/mcp-servers',
              meta: {
                title: s__('AICatalog|MCP'),
                text: s__('AICatalog|MCP'),
                indexRoute: AI_CATALOG_MCP_SERVERS_ROUTE,
              },
              children: [
                {
                  name: AI_CATALOG_MCP_SERVERS_ROUTE,
                  path: '',
                  component: AiCatalogMcpServers,
                  meta: {
                    title: s__('AICatalog|MCP'),
                  },
                },
                {
                  name: AI_CATALOG_MCP_SERVERS_NEW_ROUTE,
                  path: 'new',
                  component: AiCatalogMcpServersNew,
                  beforeEnter: (_, __, next) => {
                    if (gon.abilities?.createAiCatalogMcpServer) {
                      next();
                    } else {
                      next({ name: AI_CATALOG_MCP_SERVERS_ROUTE });
                    }
                  },
                  meta: {
                    title: s__('AICatalog|New MCP server'),
                    text: s__('AICatalog|New MCP server'),
                  },
                },
                {
                  path: ':id(\\d+)',
                  component: AiCatalogMcpServer,
                  meta: {
                    useId: true,
                  },
                  children: [
                    {
                      name: AI_CATALOG_MCP_SERVERS_SHOW_ROUTE,
                      path: '',
                      component: AiCatalogMcpServersShow,
                    },
                    {
                      name: AI_CATALOG_MCP_SERVERS_EDIT_ROUTE,
                      path: 'edit',
                      component: AiCatalogMcpServersEdit,
                      beforeEnter: (_, __, next) => {
                        if (gon.abilities?.updateAiCatalogMcpServer) {
                          next();
                        } else {
                          next({ name: AI_CATALOG_MCP_SERVERS_ROUTE });
                        }
                      },
                      meta: {
                        text: s__('AICatalog|Edit MCP server'),
                      },
                    },
                  ],
                },
              ],
            },
          ]
        : []),
      { path: '*', redirect: { name: AI_CATALOG_INDEX_ROUTE } },
    ],
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
