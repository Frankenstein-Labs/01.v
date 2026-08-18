/**
 * Shared mounting and DOM vocabulary for the Duo chat MSW integration specs,
 * both the agentic surface and the classic one.
 *
 * Helpers are added by the MR that first needs them, so nothing here is
 * unused. This file therefore grows across the series rather than arriving
 * complete.
 */
import Vue from 'vue';
import VueApollo from 'vue-apollo';
import VueRouter from 'vue-router';
import { within } from '@testing-library/vue';
import { duoChatGlobalState } from '~/super_sidebar/state';
import { CHAT_MODES } from '~/super_sidebar/constants';
import AiPanel from 'ee/ai/components/ai_panel.vue';
import { createApolloProvider } from 'ee/ai/graphql';
import { createRouter } from 'ee/ai/duo_agents_platform/router/ai_panel_router';
import {
  AGENTIC_CHAT_HISTORY_ROUTE,
  AGENTIC_CHAT_NEW_ROUTE,
  AGENTIC_CHAT_SHOW_ROUTE,
} from 'ee/ai/duo_agents_platform/router/constants';
import DuoAgenticChatStateManager from 'ee/ai/duo_agentic_chat/components/duo_agentic_chat_state_manager.vue';
import createStore from 'ee/ai/tanuki_bot/store';
import { terminate } from 'ee/ai/duo_agentic_chat/websocket/stream_manager';
import { fullMount, getText, setInputValue } from 'ee_jest/msw_integration/test_helpers';
import { installWebSocketMock, restoreWebSocket } from './websocket_mock';

Vue.use(VueApollo);
Vue.use(VueRouter);

const NAMESPACE_ID = 'gid://gitlab/Group/1';
export const PROJECT_ID = 'gid://gitlab/Project/1';

// Load-bearing for every mount: without it `checkNamespaceAvailability` disables
// the chat and the "select a default namespace" empty state masks everything else.
// Spread rather than repeated so the reason has one home.
const NAMESPACE_SELECTED_PROPS = { defaultNamespaceSelected: true };

/**
 * Mirrors the production wiring in `ee/ai/init_duo_panel.js`: the same values
 * feed `chatConfiguration.defaultProps` (consumed as route props) and the
 * `AiPanel` props (bound on `<router-view>`), so specs set them in one place.
 */
export const buildChatConfiguration = ({ defaultProps = {}, ...overrides } = {}) => ({
  agenticTitle: 'GitLab Duo Agentic Chat',
  classicTitle: 'GitLab Duo Chat',
  defaultProps: {
    isAgenticAvailable: true,
    isClassicAvailable: false,
    namespaceId: NAMESPACE_ID,
    rootNamespaceId: NAMESPACE_ID,
    ...NAMESPACE_SELECTED_PROPS,
    duoSettingsPath: '/groups/gitlab-org/-/settings/gitlab_duo',
    chatDisabledReason: '',
    isDuoDisabled: false,
    isDuoDisabledNonAdmin: false,
    // Read by `createRouter` to decide the startup route, so it belongs here
    // rather than only on the panel props.
    shouldShowBlockedState: false,
    containerType: 'group',
    canStartTrial: false,
    isTrialExpired: false,
    forceAgenticModeForCoreDuoUsers: false,
    canBuyAddon: false,
    userModelSelectionEnabled: false,
    // Required prop on the blocked-state view, always set by init_duo_panel.js.
    accessDenied: false,
    identityVerificationRequired: false,
    // Gates the Sessions tab in the navigation rail.
    isDuoAgentPlatformEnabled: true,
    ...defaultProps,
  },
  ...overrides,
});

/**
 * Classic-chat counterpart of `buildChatConfiguration`. Flipping the two
 * availability flags is what routes every rail toggle to `CLASSIC_CHAT_*` and
 * keeps `isAgenticMode` false. `autoExpand` is separately load-bearing:
 * `createRouter` starts on `CLOSED_ROUTE` without it, so no chat body renders.
 */
export const buildClassicChatConfiguration = ({ defaultProps = {}, ...overrides } = {}) =>
  buildChatConfiguration({
    autoExpand: true,
    defaultProps: {
      isAgenticAvailable: false,
      isClassicAvailable: true,
      ...defaultProps,
    },
    ...overrides,
  });

const STATE_MANAGER_PROVIDE = {
  badgeType: 'beta',
  chatConfiguration: {
    title: 'GitLab Duo Agentic Chat',
    isClassicAvailable: false,
    defaultProps: { ...NAMESPACE_SELECTED_PROPS },
  },
  activeTabData: {
    props: {
      isClassicAvailable: false,
      userId: null,
    },
  },
  duoUiNext: false,
};

// A state-manager-only mount still needs a real router, because VueRouter makes
// `$router` read-only and a `mocks: { $router }` stub cannot overwrite it. Only
// the routes the state manager pushes to are needed, plus a root route: the Vue 3
// router shim navigates to the initial location during `install()`, and without a
// match for `''` it warns, which aborts the rest of the plugin chain and leaves
// the component without `$store`. `ai_panel_router.js` carries the same route for
// the same reason.
const createStateManagerRouter = () =>
  new VueRouter({
    mode: 'abstract',
    routes: [
      { name: 'root', path: '', component: { render: () => null } },
      { name: AGENTIC_CHAT_SHOW_ROUTE, path: '/agentic-chat', component: { render: () => null } },
      {
        name: AGENTIC_CHAT_NEW_ROUTE,
        path: '/agentic-chat/new',
        component: { render: () => null },
      },
      {
        name: AGENTIC_CHAT_HISTORY_ROUTE,
        path: '/agentic-chat/history',
        component: { render: () => null },
      },
    ],
  });

const mountedWrappers = [];

// Mount helpers are wrapped so `teardownDuoChatTest` can destroy every wrapper
// itself; see its docblock for why that has to happen before `terminate()`.
const trackMountedWrapper =
  (mount) =>
  (...args) => {
    const wrapper = mount(...args);
    mountedWrappers.push(wrapper);
    return wrapper;
  };

/**
 * Mounts the whole AI sidebar (navigation rail + router + chat), which is what the
 * navigation rail, the agent picker and anything keyed off `$route.name` need.
 */
export const mountAISidebar = trackMountedWrapper(
  ({ chatConfiguration = buildChatConfiguration(), propsData = {} } = {}) => {
    const { defaultProps } = chatConfiguration;

    return fullMount(AiPanel, {
      store: createStore(),
      router: createRouter('/', 'user', chatConfiguration),
      apolloProvider: createApolloProvider(),
      propsData: {
        chatDisabledReason: defaultProps.chatDisabledReason,
        shouldShowBlockedState: defaultProps.shouldShowBlockedState,
        projectId: defaultProps.projectId,
        namespaceId: defaultProps.namespaceId,
        rootNamespaceId: defaultProps.rootNamespaceId,
        userModelSelectionEnabled: defaultProps.userModelSelectionEnabled,
        ...propsData,
      },
      provide: {
        isSidePanelView: true,
        chatConfiguration,
        badgeType: 'beta',
      },
    });
  },
);

/**
 * Mounts just the chat state manager. Cheaper than the whole panel and enough
 * for anything asserted inside `chat-component`.
 *
 * The wrapper is destroyed for us: `teardownDuoChatTest` destroys every mounted
 * wrapper, so specs neither hold on to it nor destroy it.
 */
export const mountDuoAgenticChatStateManager = trackMountedWrapper(
  ({ propsData = {}, provide = {} } = {}) =>
    fullMount(DuoAgenticChatStateManager, {
      store: createStore(),
      router: createStateManagerRouter(),
      apolloProvider: createApolloProvider(),
      propsData: {
        mode: 'active',
        exploreAiCatalogPath: '/-/ai/catalog',
        ...propsData,
      },
      provide: { ...STATE_MANAGER_PROVIDE, ...provide },
    }),
);

/**
 * Resets everything the panel persists between mounts: web storage (which holds
 * the selected model and the current workflow id) and the `duoChatGlobalState`
 * observable, which is module-scoped and therefore survives unmounting.
 *
 * `chatMode` has to be set here rather than inferred from the chat
 * configuration: it is the panel's own single source of truth for which surface
 * is active, and a classic spec that leaves it on `AGENTIC` gets agentic routes
 * from every rail toggle.
 */
export const clearPanelStorage = ({ chatMode = CHAT_MODES.AGENTIC } = {}) => {
  window.localStorage.clear();
  window.sessionStorage.clear();
  duoChatGlobalState.chatMode = chatMode;
  duoChatGlobalState.lastRoutePerTab = {};
};

/**
 * `beforeEach` body for every spec that renders the chat. Fakes the websocket
 * transport -- installed even where no prompt is sent, so that an unexpected
 * connection attempt is caught by the fake instead of reaching the real
 * `WebSocket` -- and drops panel state left behind by an earlier test.
 *
 * Specs that drive a workflow install their GraphQL handlers on top of this.
 */
export const setupDuoChatTest = ({ chatMode } = {}) => {
  installWebSocketMock();
  clearPanelStorage({ chatMode });
};

/**
 * `afterEach` counterpart. Destroys the mounted wrappers itself, before
 * `terminate()`, because `beforeDestroy` hooks read the stream manager's
 * connection state. Leaving that to VTU's `enableAutoDestroy` would invert the
 * order: `shared_test_setup.js` registers it in the root block, so it runs
 * after any `afterEach` a spec registers inside a `describe`. It still runs
 * afterwards as a safety net -- destroying twice is a no-op.
 *
 * `terminate()` is the other part worth knowing about: `stream_manager` keeps
 * its worker, subscribers and message buffer in module state, which outlives
 * the unmount, so releasing them cannot be left to the component teardown.
 */
export const teardownDuoChatTest = () => {
  try {
    mountedWrappers.forEach((wrapper) => wrapper.destroy());
  } finally {
    // Still runs if a destroy() throws, so nothing leaks into the next test.
    mountedWrappers.length = 0;
    terminate();
    restoreWebSocket();
    clearPanelStorage();
  }
};

// --- finders -----------------------------------------------------------------
// All return DOM nodes (or null) so specs assert against the real rendered DOM.

const byTestId = (testId, container = document) =>
  container.querySelector(`[data-testid="${testId}"]`);

const findChatInput = () => byTestId('chat-prompt-input');
const findChatForm = () => byTestId('chat-prompt-form');

export const findSubmitButton = () => byTestId('chat-prompt-submit-button');

export const findChatToggle = () => byTestId('ai-chat-toggle');
export const findHistoryToggle = () => byTestId('ai-history-toggle');
export const findSessionsToggle = () => byTestId('ai-sessions-toggle');

// The blocked state replaces the usual tabs when Duo is off for the container.
// Named for its testid rather than `findEmptyState`, which the chat's own
// `gl-duo-chat-empty-state` takes.
export const findDuoDisabledToggle = () => byTestId('duo-disabled-toggle');
export const findDuoDisabledEmptyState = () => byTestId('duo-disabled-empty-state');
export const findDuoSettingsCta = () => byTestId('duo-settings-cta');

export const findDuoAgenticChatPanel = () => byTestId('duo-agentic-chat');
export const findThreadListPanel = () => byTestId('duo-chat-threads');
export const findAgentSessionsPanel = () => byTestId('agent-sessions');

/** The individual rows of the thread list found by `findThreadListPanel`. */
export const findThreadBoxes = () =>
  document.querySelectorAll('[data-testid="chat-threads-thread-box"]');

/** The history row whose title holds `text`, or null. */
export const findThreadBoxWithText = (text) =>
  Array.from(findThreadBoxes()).find((box) => box.textContent.includes(text)) ?? null;

/**
 * The rendered conversation, and the container to make message assertions
 * against: a prompt string also appears in the thread list that titles a
 * conversation after it, so asserting on the document cannot tell "the chat
 * replied" apart from "the chat is listed in history".
 */
export const findChatMessages = () => byTestId('chat-messages');

export const findChatComponent = () => byTestId('chat-component');
export const findEmptyState = () => byTestId('gl-duo-chat-empty-state');
export const findCancelButton = () => byTestId('chat-prompt-cancel-button');
export const findMessages = () => document.querySelectorAll('.duo-chat-message');

/** Finds a button by accessible name anywhere in the document. */
export const findButton = (name, container = document.body) =>
  within(container).queryAllByRole('button', { name })[0] || null;

export const findPanelHeading = () => byTestId('content-container-title');
export const panelHeadingText = () => {
  const heading = findPanelHeading();
  return heading === null ? null : getText(heading);
};

// The prompt footer is the cleanest discriminator between the classic chat view
// and the history list: the list hides it, the conversation shows it. Both are
// asserted through the DOM because this suite bans reaching into the router or
// the route-derived computeds.
export const isShowingClassicChatView = () => byTestId('chat-footer') !== null;
export const isShowingClassicListView = () => findThreadBoxes().length > 0;

export const findApproveButton = () => byTestId('approve-tool-inline');
export const findDenyButton = () => byTestId('deny-tool-inline');

// The row testids come from duo-ui's `message_tool_row.vue`, the metadata chip
// from `message_tool.vue` -- hence the two prefixes.
export const findToolRowLabel = () => byTestId('tool-row-label');
export const findToolRowSecondary = () => byTestId('tool-row-secondary');
export const findToolMessageProjectInfo = () => byTestId('tool-message-project-info');

// --- interactions ------------------------------------------------------------

/**
 * Submits a prompt. The send is wired to `@submit.stop.prevent` on `gl-form`,
 * so dispatching `submit` on the form is the DOM equivalent of pressing Enter.
 */
export const sendPrompt = (text) => {
  setInputValue(findChatInput(), text);
  findChatForm().dispatchEvent(new Event('submit', { bubbles: true, cancelable: true }));
};

export const cancelPrompt = () => findCancelButton().click();

export const openChatTab = () => findChatToggle().click();
export const openHistoryTab = () => findHistoryToggle().click();

export const approveTool = () => findApproveButton().click();
