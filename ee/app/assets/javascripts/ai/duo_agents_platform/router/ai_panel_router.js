import Vue from 'vue';
import VueRouter from 'vue-router';
import { s__, __ } from '~/locale';
import NestedRouteApp from '~/vue_shared/spa/components/router_view.vue';
import { duoChatGlobalState } from '~/super_sidebar/state';
import { removeSessionStorageValue } from '~/lib/utils/local_storage';
import { CHAT_MODES } from '~/super_sidebar/constants';
import { eventHub, SHOW_SESSION, SHOW_NEW_CHAT } from 'ee/ai/events/panel';
import { DUO_CURRENT_WORKFLOW_STORAGE_KEY } from 'ee/ai/constants';
import { SIDE_PANEL_ROUTE_CONTEXT } from 'ee/ai/duo_agents_platform/constants';
import DuoAgenticChat from 'ee/ai/duo_agentic_chat/components/duo_agentic_chat_state_manager.vue';
import DuoAgenticChatBlockedStateView from 'ee/ai/duo_agentic_chat/components/duo_agentic_chat_blocked_state_view.vue';
import DuoChat from 'ee/ai/tanuki_bot/components/duo_chat_state_manager.vue';
import AgentsPlatformShow from '../pages/show/duo_agents_platform_show.vue';
import {
  getStorageKey,
  restoreLastRoute,
  saveRouteState,
  setupNavigationGuards,
  trackTabRoutes,
} from '../utils/navigation_state';
import { safeRouterPush } from '../utils/router_utils';
import {
  AGENTS_PLATFORM_INDEX_ROUTE,
  AGENTS_PLATFORM_SHOW_ROUTE,
  AGENTIC_CHAT_HISTORY_ROUTE,
  AGENTIC_CHAT_NEW_ROUTE,
  AGENTIC_CHAT_SHOW_ROUTE,
  AGENTIC_CHAT_BLOCKED_ROUTE,
  CLASSIC_CHAT_HISTORY_ROUTE,
  CLASSIC_CHAT_NEW_ROUTE,
  CLASSIC_CHAT_SHOW_ROUTE,
  CLOSED_ROUTE,
} from './constants';
import { getNamespaceIndexComponent } from './utils';

Vue.use(VueRouter);

// Sets up panel-level event hub subscriptions for routing intents.
// Returns a teardown function that removes both listeners — callers must
// invoke it when the router is being discarded so the module-level
// `eventHub` does not leak handlers across re-mounts (HMR, integration
// tests, future SPA navigation that re-runs `initDuoPanel`).
const setupRouterPanelEvents = (router, isAgenticAvailable) => {
  const onShowSession = async ({ id }) => {
    await safeRouterPush(
      router,
      { name: AGENTS_PLATFORM_SHOW_ROUTE, params: { id } },
      { component: 'AiPanelRouter' },
    );
  };

  const onShowNewChat = async () => {
    const isAgenticMode = isAgenticAvailable && duoChatGlobalState.chatMode === CHAT_MODES.AGENTIC;
    const routeName = isAgenticMode ? AGENTIC_CHAT_NEW_ROUTE : CLASSIC_CHAT_NEW_ROUTE;
    await safeRouterPush(router, { name: routeName }, { component: 'AiPanelRouter' });
  };

  eventHub.$on(SHOW_SESSION, onShowSession);
  eventHub.$on(SHOW_NEW_CHAT, onShowNewChat);

  return () => {
    eventHub.$off(SHOW_SESSION, onShowSession);
    eventHub.$off(SHOW_NEW_CHAT, onShowNewChat);
  };
};

export const createRouter = (base, namespace, chatConfiguration) => {
  const { defaultProps = {} } = chatConfiguration;

  const router = new VueRouter({
    base,
    mode: 'abstract',
    routes: [
      {
        name: 'root',
        path: '',
        component: { render: () => null },
      },
      {
        name: CLOSED_ROUTE,
        path: '/closed',
        component: { render: () => null },
      },
      {
        name: AGENTIC_CHAT_SHOW_ROUTE,
        path: '/agentic-chat',
        component: DuoAgenticChat,
        props: { ...defaultProps, mode: 'active' },
        meta: {
          text: s__('DuoAgentsPlatform|Chat'),
          title: chatConfiguration.agenticTitle,
        },
      },
      {
        name: AGENTIC_CHAT_NEW_ROUTE,
        path: '/agentic-chat/new',
        component: DuoAgenticChat,
        props: { ...defaultProps, mode: 'new' },
        meta: {
          text: s__('DuoAgentsPlatform|Chat'),
          title: chatConfiguration.agenticTitle,
        },
      },
      {
        name: AGENTIC_CHAT_HISTORY_ROUTE,
        path: '/agentic-chat/history',
        component: DuoAgenticChat,
        props: { ...defaultProps, mode: 'history' },
        meta: { title: __('History') },
      },
      {
        name: AGENTIC_CHAT_BLOCKED_ROUTE,
        path: '/agentic-chat/blocked',
        component: DuoAgenticChatBlockedStateView,
        props: { ...defaultProps, mode: 'chat' },
        meta: { text: s__('DuoAgentsPlatform|Chat'), title: chatConfiguration.agenticTitle },
      },
      {
        name: CLASSIC_CHAT_SHOW_ROUTE,
        // Optional numeric id restores the open conversation across a reload.
        // Constrained to digits so it cannot swallow the /new route below.
        path: '/classic-chat/:id(\\d+)?',
        component: DuoChat,
        props: { ...defaultProps, mode: 'chat' },
        meta: {
          text: s__('DuoAgentsPlatform|Chat'),
          title: chatConfiguration.classicTitle,
        },
      },
      {
        name: CLASSIC_CHAT_NEW_ROUTE,
        path: '/classic-chat/new',
        component: DuoChat,
        props: { ...defaultProps, mode: 'new' },
        meta: {
          text: s__('DuoAgentsPlatform|Chat'),
          title: chatConfiguration.classicTitle,
        },
      },
      {
        name: CLASSIC_CHAT_HISTORY_ROUTE,
        path: '/classic-chat/history',
        component: DuoChat,
        props: { ...defaultProps, mode: 'history' },
        meta: { title: __('History') },
      },

      {
        component: NestedRouteApp,
        path: '/agent-sessions',
        meta: {
          text: s__('DuoAgentsPlatform|Sessions'),
          title: __('Sessions'),
        },
        children: [
          {
            name: AGENTS_PLATFORM_INDEX_ROUTE,
            path: '',
            component: getNamespaceIndexComponent(namespace),
          },
          {
            name: AGENTS_PLATFORM_SHOW_ROUTE,
            path: ':id(\\d+)',
            component: AgentsPlatformShow,
            beforeEnter(to, _from, next) {
              saveRouteState(to, getStorageKey(SIDE_PANEL_ROUTE_CONTEXT));
              next();
            },
          },
        ],
      },
    ],
  });

  // Set up navigation guards for session state persistence (enabled for side panels)
  setupNavigationGuards({
    router,
    context: SIDE_PANEL_ROUTE_CONTEXT,
  });

  // Track how many navigations have completed so consumers can decide whether
  // a "back" action makes sense without touching vue-router internals like
  // `router.history.index` (which is not part of the public API).
  let navigationCount = 0;
  router.afterEach(() => {
    navigationCount += 1;
  });
  router.canGoBack = () => navigationCount > 1;

  // Track routes for AI panel tab navigation
  router.beforeEach((to, _from, next) => {
    if (to.name === AGENTIC_CHAT_NEW_ROUTE || to.name === CLASSIC_CHAT_NEW_ROUTE) {
      removeSessionStorageValue(DUO_CURRENT_WORKFLOW_STORAGE_KEY);
    }
    trackTabRoutes(to);
    next();
  });

  const isAgenticAvailable = defaultProps.isAgenticAvailable ?? false;

  // Attach a teardown so the panel can dispose event-hub listeners when it
  // unmounts. Without this, `eventHub.$on` accumulates handlers across
  // re-mounts and `SHOW_NEW_CHAT` would push routes N times.
  router.cleanupEventListeners = setupRouterPanelEvents(router, isAgenticAvailable);

  // Fire-and-forget so `createRouter` stays synchronous. Safe because
  // the `<router-view>` is gated on `isPanelOpen`, which only becomes
  // truthy once the route resolves.
  restoreLastRoute(router, {
    context: SIDE_PANEL_ROUTE_CONTEXT,
    defaultRoute: chatConfiguration.autoExpand ? undefined : CLOSED_ROUTE,
    blockedRoute: AGENTIC_CHAT_BLOCKED_ROUTE,
    isAgenticAvailable,
    shouldShowBlockedState: defaultProps.shouldShowBlockedState,
    autoExpand: chatConfiguration.autoExpand,
  });

  return router;
};
