import { isEqual } from 'lodash-es';
import {
  getSessionStorageValue,
  saveSessionStorageValue,
  removeSessionStorageValue,
} from '~/lib/utils/local_storage';
import { CHAT_MODES } from '~/super_sidebar/constants';
import { duoChatGlobalState } from '~/super_sidebar/state';
import { AGENTIC_CHAT_NEW_ROUTE, CLASSIC_CHAT_NEW_ROUTE, ROUTE_TO_TAB } from '../router/constants';
import { getDefaultRouteForTab } from '../router/utils';
import { safeRouterPush } from './router_utils';

// Routes that trigger side-effects (e.g. creating a new chat session) and
// must not be replayed when restoring the history stack on a fresh page load.
const TRANSIENT_ROUTES = new Set([AGENTIC_CHAT_NEW_ROUTE, CLASSIC_CHAT_NEW_ROUTE]);

const BASE_STORAGE_KEY = 'duo_agents_platform_last_route';
const BASE_HISTORY_STACK_KEY = 'duo_agents_platform_history_stack';
const MAX_HISTORY_STACK_SIZE = 200;

export const getStorageKey = (context) =>
  context ? `${BASE_STORAGE_KEY}_${context}` : BASE_STORAGE_KEY;

export const getLastRouteState = (storageKey = BASE_STORAGE_KEY) => {
  const { exists, value } = getSessionStorageValue(storageKey);
  return exists ? value : null;
};

export const saveRouteState = (route, storageKey = BASE_STORAGE_KEY) => {
  if (route.name) {
    saveSessionStorageValue(storageKey, {
      name: route.name,
      params: route.params || {},
    });
  }
};

export const clearRouteState = (storageKey = BASE_STORAGE_KEY) => {
  removeSessionStorageValue(storageKey);
};

export const getHistoryStackKey = (context) =>
  context ? `${BASE_HISTORY_STACK_KEY}_${context}` : BASE_HISTORY_STACK_KEY;

/**
 * Pure data transform: reads the abstract router's in-memory history,
 * drops forward-history (entries after `index`), caps at
 * MAX_HISTORY_STACK_SIZE (oldest dropped first), and returns an array
 * of serialisable { name, params } objects.
 *
 * Returns an empty array when the history is missing or empty.
 */
export const serializeHistoryStack = (router) => {
  const { stack, index } = router.history ?? {};

  if (!Array.isArray(stack) || stack.length === 0) {
    return [];
  }

  const truncated = stack.slice(0, index + 1);
  const cappedStart = Math.max(0, truncated.length - MAX_HISTORY_STACK_SIZE);
  return truncated
    .slice(cappedStart)
    .filter((route) => !TRANSIENT_ROUTES.has(route.name))
    .map((route) => ({
      name: route.name,
      params: route.params || {},
    }));
};

/**
 * Imperative wrapper: serializes the router's history stack and writes
 * the result to sessionStorage. No-ops when the stack is empty.
 */
export const saveHistoryStack = (router, storageKey) => {
  const entries = serializeHistoryStack(router);

  if (entries.length > 0) {
    saveSessionStorageValue(storageKey, entries);
  }
};

/**
 * Reads a persisted history stack from sessionStorage.
 * If any entries are invalid, return an empty array and
 * start the history fresh.
 */
export const getHistoryStack = (storageKey) => {
  const { exists, value } = getSessionStorageValue(storageKey);

  if (!exists || !Array.isArray(value)) {
    return [];
  }

  const isValid = value.every(
    (entry) => entry !== null && entry !== undefined && typeof entry.name === 'string',
  );

  return isValid ? value : [];
};

/**
 * Returns the mode-aware default route name. Used as the fallback
 * destination when there is nothing meaningful to restore.
 */
export const getModeAwareDefaultRoute = ({ defaultRoute, isAgenticAvailable } = {}) => {
  if (defaultRoute) return defaultRoute;
  const isAgenticMode = isAgenticAvailable && duoChatGlobalState.chatMode === CHAT_MODES.AGENTIC;
  return getDefaultRouteForTab('chat', isAgenticMode);
};

/**
 * Replays a serialized history stack through the router so
 * `router.back()` works after a page reload.
 */
const replayHistoryStack = async (router, stack) => {
  for (const entry of stack) {
    // eslint-disable-next-line no-await-in-loop
    await safeRouterPush(router, entry, { component: 'NavigationState' });
  }
};

/**
 * Registers an afterEach guard that persists the router's history stack
 * to sessionStorage on every navigation. Extracted so it can be called
 * from multiple code paths inside `restoreLastRoute`.
 */
const registerHistoryStackGuard = (router, historyKey) => {
  router.afterEach(() => {
    if (window.gon?.features?.duoPanelHistoryStackPersistence) {
      saveHistoryStack(router, historyKey);
    }
  });
};

export const restoreLastRoute = async (router, options = {}) => {
  const {
    defaultRoute = null,
    context = null,
    storageKey = null,
    isAgenticAvailable = false,
    shouldShowBlockedState = false,
    blockedRoute = '',
    autoExpand = false,
  } = options;
  const key = storageKey || getStorageKey(context);
  const isHistoryStackEnabled = Boolean(window.gon?.features?.duoPanelHistoryStackPersistence);
  const historyKey = getHistoryStackKey(context);

  const routeState = getLastRouteState(key);

  // Show the blocked state view only when the panel should auto-expand or the
  // user has a non-default saved route to restore (i.e. they were actively
  // using the panel before reload). A saved route that matches the default
  // route means the user had the panel in its initial/closed state, so we
  // must not force-open the blocked view.
  const hasNonDefaultSavedRoute = routeState && routeState.name !== defaultRoute;
  if (shouldShowBlockedState && (autoExpand || hasNonDefaultSavedRoute)) {
    // Clear stale history stack so it is not replayed on the next load
    // when the blocked state may no longer apply.
    if (isHistoryStackEnabled) {
      removeSessionStorageValue(historyKey);
    }
    await safeRouterPush(router, { name: blockedRoute }, { component: 'NavigationState' });
    return;
  }

  // When the feature flag is enabled, attempt to replay the full persisted
  // history stack so router.back() works after a page reload.
  if (isHistoryStackEnabled) {
    const stack = getHistoryStack(historyKey);

    // Only replay when the stack's tip matches the separately-persisted
    // routeState. A mismatch means a full-page navigation occurred (e.g.
    // switching projects) and the stack belongs to the previous page.
    const lastEntry = stack.length > 0 ? stack[stack.length - 1] : null;
    const isStackFresh =
      lastEntry &&
      routeState &&
      lastEntry.name === routeState.name &&
      isEqual(lastEntry.params || {}, routeState.params || {});

    if (isStackFresh) {
      try {
        await replayHistoryStack(router, stack);
      } catch {
        removeSessionStorageValue(historyKey);
        const fallback = getModeAwareDefaultRoute({ defaultRoute, isAgenticAvailable });
        await safeRouterPush(router, { name: fallback }, { component: 'NavigationState' });
      }
      // Register the guard to persist the stack on every navigation and
      // return — the replayed stack already positioned the router.
      registerHistoryStackGuard(router, historyKey);
      return;
    }

    // Stack is empty or stale — fall through to the normal route
    // restoration below so that routeState / defaultRoute logic still
    // applies, but register the guard so future navigations start being
    // persisted.
    if (lastEntry && !isStackFresh) {
      removeSessionStorageValue(historyKey);
    }
    registerHistoryStackGuard(router, historyKey);
  }

  if (routeState?.name === defaultRoute) {
    await safeRouterPush(router, routeState, { component: 'NavigationState' });
    return;
  }

  if (!routeState) {
    const fallback = getModeAwareDefaultRoute({ defaultRoute, isAgenticAvailable });
    await safeRouterPush(router, { name: fallback }, { component: 'NavigationState' });
    return;
  }

  // Check if current route already matches the saved route
  const { currentRoute } = router;
  if (
    currentRoute &&
    currentRoute.name === routeState.name &&
    isEqual(currentRoute.params, routeState.params || {})
  ) {
    return;
  }

  // Try to restore saved route, fall back to mode-aware default on error
  try {
    await safeRouterPush(router, routeState, { component: 'NavigationState' });
  } catch (err) {
    if (err.name === 'NavigationDuplicated') return;
    clearRouteState(key);
    const fallback = getModeAwareDefaultRoute({ defaultRoute, isAgenticAvailable });
    await safeRouterPush(router, { name: fallback }, { component: 'NavigationState' });
  }
};

export const setupNavigationGuards = ({ router, context = null, storageKey = null }) => {
  const key = storageKey || getStorageKey(context);

  router.afterEach((to) => {
    saveRouteState(to, key);
  });
};

export const trackTabRoutes = ({ name, path }) => {
  const activeTab = ROUTE_TO_TAB[name];
  const { lastRoutePerTab } = duoChatGlobalState;

  if (!activeTab || !path) {
    return;
  }

  if (!lastRoutePerTab) {
    duoChatGlobalState.lastRoutePerTab = {};
  }

  duoChatGlobalState.lastRoutePerTab = { ...duoChatGlobalState.lastRoutePerTab, [activeTab]: path };
};
